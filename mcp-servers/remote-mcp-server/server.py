#!/usr/bin/env python3
"""
Remote MCP Server — OpenProject + AWS S3
Uses the official MCP Python SDK (FastMCP) for proper JSON-RPC 2.0 protocol.

Auth: MCP_API_KEY env var, checked via:
  - Query param:  ?key=<key>   (for clients that can't send custom headers)
  - Header:       X-MCP-Key: <key>
"""

import os
import json
import base64

import httpx
import boto3
from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings  # noqa: F401
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp, Receive, Scope, Send

# ---- Configuration ----
OP_URL = os.environ.get("OPENPROJECT_URL", "https://projects.axinagroup.com")
OP_API_KEY = os.environ.get("OPENPROJECT_API_KEY", "")
MCP_API_KEY = os.environ.get("MCP_API_KEY", "")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
S3_BUCKETS = os.environ.get("S3_BUCKETS", "xgccloud-openproject-files").split(",")

# Disable DNS rebinding protection — nginx is the trusted reverse proxy
_no_dns_rebind = TransportSecuritySettings(enable_dns_rebinding_protection=False)

# ---- MCP Server ----
# mount_path="/mcp" makes FastMCP advertise /mcp/messages/ in SSE event data
# so mcp-proxy posts to the nginx-proxied path, not bare /messages/
mcp = FastMCP(
    "AXINA Group MCP Server",
    auth=None,
    host="0.0.0.0",
    port=39128,
    transport_security=_no_dns_rebind,
    mount_path="/mcp",
)

# ---- S3 client (uses EC2 IAM role automatically) ----
s3_client = boto3.client("s3", region_name=AWS_REGION)


# ---- OpenProject helper ----
def _op_auth() -> dict:
    token = base64.b64encode(f"apikey:{OP_API_KEY}".encode()).decode()
    return {"Authorization": f"Basic {token}", "Content-Type": "application/json"}


def op_get(endpoint: str) -> dict:
    with httpx.Client(verify=True, timeout=30) as client:
        r = client.get(f"{OP_URL}/api/v3/{endpoint}", headers=_op_auth())
        if r.status_code >= 400:
            return {"error": f"OpenProject {r.status_code}", "detail": r.text}
        return r.json()


def op_post(endpoint: str, data: dict) -> dict:
    with httpx.Client(verify=True, timeout=30) as client:
        r = client.post(f"{OP_URL}/api/v3/{endpoint}", headers=_op_auth(), json=data)
        if r.status_code >= 400:
            return {"error": f"OpenProject {r.status_code}", "detail": r.text}
        return r.json()


# ---- OpenProject Tools ----

@mcp.tool()
def list_projects() -> str:
    """List all OpenProject projects."""
    result = op_get("projects")
    projects = [
        {
            "id": p.get("id"),
            "name": p.get("name"),
            "identifier": p.get("identifier"),
            "description": p.get("description", {}).get("raw", ""),
        }
        for p in result.get("_embedded", {}).get("elements", [])
    ]
    return json.dumps({"projects": projects}, indent=2)


@mcp.tool()
def get_project(project_id: str) -> str:
    """Get details of a specific OpenProject project.

    Args:
        project_id: Project identifier or numeric ID
    """
    return json.dumps(op_get(f"projects/{project_id}"), indent=2)


@mcp.tool()
def create_work_package(
    project_id: str,
    subject: str,
    description: str = "",
    type: str = "Task",
    priority: str = "normal",
) -> str:
    """Create a work package in an OpenProject project.

    Args:
        project_id: Project identifier or numeric ID
        subject: Work package subject/title
        description: Optional description
        type: Type: Task, Milestone, Bug, Feature, Epic
        priority: Priority: low, normal, high, urgent
    """
    # Resolve type href from the project's available types
    type_href = None
    types_result = op_get(f"projects/{project_id}/types")
    for t in types_result.get("_embedded", {}).get("elements", []):
        if t.get("name", "").lower() == type.lower():
            type_href = t.get("_links", {}).get("self", {}).get("href")
            break
    if not type_href:
        elements = types_result.get("_embedded", {}).get("elements", [])
        if elements:
            type_href = elements[0].get("_links", {}).get("self", {}).get("href")

    data: dict = {
        "subject": subject,
        "description": {"raw": description},
        "_links": {
            "project": {"href": f"/api/v3/projects/{project_id}"},
        },
    }
    if type_href:
        data["_links"]["type"] = {"href": type_href}
    return json.dumps(op_post("work_packages", data), indent=2)


@mcp.tool()
def list_work_packages(project_id: str, status: str = "") -> str:
    """List work packages in an OpenProject project.

    Args:
        project_id: Project identifier or numeric ID
        status: Optional status filter (open, closed, in progress)
    """
    endpoint = f"projects/{project_id}/work_packages"
    if status:
        endpoint += f'?filters=[{{"status":{{"operator":"=","values":["{status}"]}}}}]'
    result = op_get(endpoint)
    packages = [
        {
            "id": wp.get("id"),
            "subject": wp.get("subject"),
            "status": wp.get("_links", {}).get("status", {}).get("title", ""),
            "type": wp.get("_links", {}).get("type", {}).get("title", ""),
            "assignee": wp.get("_links", {}).get("assignee", {}).get("title", "Unassigned"),
        }
        for wp in result.get("_embedded", {}).get("elements", [])
    ]
    return json.dumps(
        {"project_id": project_id, "work_packages": packages, "count": len(packages)},
        indent=2,
    )


# ---- S3 Tools ----

@mcp.tool()
def list_s3_buckets() -> str:
    """List accessible S3 buckets."""
    response = s3_client.list_buckets()
    all_buckets = [b["Name"] for b in response["Buckets"]]
    accessible = [b for b in all_buckets if b in S3_BUCKETS]
    return json.dumps({"buckets": accessible, "all_available": all_buckets}, indent=2)


@mcp.tool()
def list_s3_objects(bucket: str, prefix: str = "", max_keys: int = 50) -> str:
    """List objects in an S3 bucket with optional prefix.

    Args:
        bucket: S3 bucket name
        prefix: Optional prefix/folder path
        max_keys: Maximum objects to return (default 50)
    """
    response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix, MaxKeys=max_keys)
    objects = [
        {
            "key": o["Key"],
            "size": o["Size"],
            "last_modified": o["LastModified"].isoformat(),
        }
        for o in response.get("Contents", [])
    ]
    return json.dumps(
        {
            "bucket": bucket,
            "prefix": prefix,
            "objects": objects,
            "count": len(objects),
            "truncated": response.get("IsTruncated", False),
        },
        indent=2,
    )


@mcp.tool()
def get_s3_object(bucket: str, key: str) -> str:
    """Get contents of an S3 object (text files, truncated at 10KB).

    Args:
        bucket: S3 bucket name
        key: S3 object key
    """
    response = s3_client.get_object(Bucket=bucket, Key=key)
    content = response["Body"].read().decode("utf-8", errors="replace")
    return json.dumps(
        {
            "bucket": bucket,
            "key": key,
            "content_type": response.get("ContentType", "unknown"),
            "size": response["ContentLength"],
            "content": content[:10000],
            "truncated": len(content) > 10000,
        },
        indent=2,
    )


@mcp.tool()
def search_s3_objects(query: str, bucket: str = "") -> str:
    """Search for files in S3 buckets matching a pattern.

    Args:
        query: Search query matched against object keys (case-insensitive)
        bucket: Specific bucket to search (searches all configured buckets if omitted)
    """
    buckets_to_search = [bucket] if bucket else S3_BUCKETS
    results = []
    for b in buckets_to_search:
        try:
            for page in s3_client.get_paginator("list_objects_v2").paginate(Bucket=b, MaxKeys=1000):
                results += [
                    {
                        "bucket": b,
                        "key": o["Key"],
                        "size": o["Size"],
                        "last_modified": o["LastModified"].isoformat(),
                    }
                    for o in page.get("Contents", [])
                    if query.lower() in o["Key"].lower()
                ]
        except Exception as e:
            results.append({"bucket": b, "error": str(e)})
    return json.dumps({"query": query, "results": results, "count": len(results)}, indent=2)


# ---- Auth Middleware ----
# Pure ASGI middleware — BaseHTTPMiddleware buffers streaming responses and
# breaks SSE on Starlette 1.0.0+.
class APIKeyMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or not MCP_API_KEY:
            await self.app(scope, receive, send)
            return
        request = Request(scope)
        path = request.url.path
        # /mcp/messages/ carries a session_id issued after SSE auth — allow through
        # /health is public for monitoring
        if "/messages/" in path or path.endswith("/health"):
            await self.app(scope, receive, send)
            return
        key = request.query_params.get("key") or request.headers.get("x-mcp-key")
        if key != MCP_API_KEY:
            response = Response("Unauthorized", status_code=401)
            await response(scope, receive, send)
            return
        await self.app(scope, receive, send)


# ---- ASGI App (SSE transport) ----
app = mcp.sse_app()
app.add_middleware(APIKeyMiddleware)  # type: ignore[attr-defined]


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=39128, log_level="info")
