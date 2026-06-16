#!/usr/bin/env python3
"""
create_company.py — Idempotent ERPNext v16 Company + Address provisioner.

Usage:
    python create_company.py
    python create_company.py --dry-run      # validate payload, skip writes
    python create_company.py --delete AGI   # remove company by abbr (dev only)

Environment variables (required unless overridden in CONFIG below):
    AXERP_URL        Base URL of the ERP instance, e.g. https://erp.axinagroup.com
    AXERP_API_KEY    Frappe token key   (Settings → My Account → API Access)
    AXERP_API_SECRET Frappe token secret

Exit codes:
    0  success (created or already existed)
    1  unrecoverable error
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

import requests

# ---------------------------------------------------------------------------
# Configuration — override with environment variables in production
# ---------------------------------------------------------------------------
CONFIG: dict[str, str] = {
    "url":        os.getenv("AXERP_URL",        "https://erp.axinagroup.com"),
    "api_key":    os.getenv("AXERP_API_KEY",    ""),
    "api_secret": os.getenv("AXERP_API_SECRET", ""),
}

# ---------------------------------------------------------------------------
# Company payload — all mandatory and recommended fields for a US enterprise
# ---------------------------------------------------------------------------
COMPANY_PAYLOAD: dict[str, Any] = {
    "company_name":    "Axina Group Inc.",
    "abbr":            "AGI",
    "default_currency": "USD",
    "country":         "United States",
    "domain":          "Services",
    "website":         "https://axinagroup.com/",
    "email":           "db@axinagroup.com",
    "date_of_establishment": "2020-01-01",
    "fiscal_year_end_month": "December",
    "create_chart_of_accounts_based_on": "Standard Template",
    "chart_of_accounts": "Standard",
    "enable_perpetual_inventory": 1,
    "auto_exchange_rate_revaluation": 0,
    "company_description": (
        "Axina Group Inc. (DBA Axina Group Inc.) is a Florida-registered enterprise "
        "headquartered at 1801 NE 123rd St Suite 314, North Miami, FL 33181, USA. "
        "The company delivers sustainable infrastructure, carbon sovereignty solutions, "
        "and project management services across international markets."
    ),
}

# ---------------------------------------------------------------------------
# Address payload — separate Doctype, linked via `links` child table
# ---------------------------------------------------------------------------
ADDRESS_PAYLOAD: dict[str, Any] = {
    "address_title":    "Axina Group Inc.",
    "address_type":     "Office",
    "address_line1":    "1801 NE 123rd St",
    "address_line2":    "Suite 314",
    "city":             "North Miami",
    "state":            "FL",
    "pincode":          "33181",
    "country":          "United States",
    "email_id":         "db@axinagroup.com",
    "is_primary_address": 1,
    "is_shipping_address": 1,
    "links": [
        {"link_doctype": "Company", "link_name": "Axina Group Inc."}
    ],
}


# ---------------------------------------------------------------------------
# HTTP client
# ---------------------------------------------------------------------------

class ERPClient:
    """Thin wrapper around requests for Frappe v16 REST API."""

    def __init__(self, base_url: str, api_key: str, api_secret: str) -> None:
        self.base = base_url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"token {api_key}:{api_secret}",
            "Content-Type":  "application/json",
            "Accept":        "application/json",
        })

    # ------------------------------------------------------------------
    def get(self, doctype: str, name: str) -> dict | None:
        """Return doc dict if found, None if 404, raise on other errors."""
        url = f"{self.base}/api/resource/{doctype}/{requests.utils.quote(name)}"
        resp = self.session.get(url)
        if resp.status_code == 404:
            return None
        _raise_for_frappe(resp)
        return resp.json().get("data", {})

    # ------------------------------------------------------------------
    def exists(self, doctype: str, name: str) -> bool:
        return self.get(doctype, name) is not None

    # ------------------------------------------------------------------
    def create(self, doctype: str, payload: dict) -> dict:
        """POST to create a new doc; returns the created doc dict."""
        url  = f"{self.base}/api/resource/{doctype}"
        resp = self.session.post(url, data=json.dumps(payload))
        _raise_for_frappe(resp)
        return resp.json().get("data", {})

    # ------------------------------------------------------------------
    def update(self, doctype: str, name: str, payload: dict) -> dict:
        """PUT to update an existing doc; returns updated doc dict."""
        url  = f"{self.base}/api/resource/{doctype}/{requests.utils.quote(name)}"
        resp = self.session.put(url, data=json.dumps(payload))
        _raise_for_frappe(resp)
        return resp.json().get("data", {})

    # ------------------------------------------------------------------
    def delete(self, doctype: str, name: str) -> None:
        url  = f"{self.base}/api/resource/{doctype}/{requests.utils.quote(name)}"
        resp = self.session.delete(url)
        _raise_for_frappe(resp)

    # ------------------------------------------------------------------
    def ping(self) -> bool:
        """Verify authentication before running any writes."""
        url  = f"{self.base}/api/method/frappe.auth.get_logged_user"
        resp = self.session.get(url)
        if resp.status_code != 200:
            return False
        user = resp.json().get("message", "")
        print(f"  ✓ Authenticated as: {user}")
        return bool(user)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _raise_for_frappe(resp: requests.Response) -> None:
    """Raise a clear RuntimeError that includes the Frappe traceback if any."""
    if resp.status_code in (200, 201):
        return
    try:
        body = resp.json()
    except ValueError:
        body = {"raw": resp.text[:500]}

    exc     = body.get("exception", "")
    server  = body.get("_server_messages", "")
    detail  = exc or server or json.dumps(body, indent=2)[:500]
    raise RuntimeError(
        f"HTTP {resp.status_code} from {resp.url}\n{detail}"
    )


def _validate_config(cfg: dict[str, str]) -> None:
    missing = [k for k, v in cfg.items() if not v]
    if missing:
        print(f"[ERROR] Missing configuration: {', '.join(missing)}")
        print("        Set AXERP_URL, AXERP_API_KEY, AXERP_API_SECRET environment variables.")
        sys.exit(1)


# ---------------------------------------------------------------------------
# Main provisioning logic
# ---------------------------------------------------------------------------

def provision_company(client: ERPClient, dry_run: bool = False) -> None:
    """
    Idempotently create or update Axina Group Inc. and its Office address.
    Steps:
      1. Check if Company already exists.
      2. If not → POST create.
      3. If yes  → PUT update (keeps abbr, currency, chart of accounts).
      4. Check if Address for this company already exists.
      5. If not → POST create Address linked to Company.
    """
    company_name = COMPANY_PAYLOAD["company_name"]
    address_title = f"{ADDRESS_PAYLOAD['address_title']}-{ADDRESS_PAYLOAD['address_type']}"

    # ── 1. Company ──────────────────────────────────────────────────────────
    print(f"\n[1/2] Company: {company_name}")

    existing_company = client.exists("Company", company_name)

    if existing_company:
        print(f"  → Already exists — updating details.")
        if not dry_run:
            # Do not resend chart_of_accounts on update (it triggers re-creation of CoA)
            update_fields = {k: v for k, v in COMPANY_PAYLOAD.items()
                             if k not in ("create_chart_of_accounts_based_on", "chart_of_accounts")}
            doc = client.update("Company", company_name, update_fields)
            print(f"  ✓ Updated: {doc.get('name')} | abbr={doc.get('abbr')} | currency={doc.get('default_currency')}")
        else:
            print("  [dry-run] Would PUT update company fields.")
    else:
        print(f"  → Does not exist — creating.")
        if not dry_run:
            doc = client.create("Company", COMPANY_PAYLOAD)
            print(f"  ✓ Created: {doc.get('name')} | abbr={doc.get('abbr')} | currency={doc.get('default_currency')}")
        else:
            print("  [dry-run] Would POST create company.")

    # ── 2. Address ──────────────────────────────────────────────────────────
    print(f"\n[2/2] Address: {address_title}")

    existing_address = client.exists("Address", address_title)

    if existing_address:
        print(f"  → Already exists — updating.")
        if not dry_run:
            addr = client.update("Address", address_title, ADDRESS_PAYLOAD)
            print(f"  ✓ Updated: {addr.get('name')}")
        else:
            print("  [dry-run] Would PUT update address.")
    else:
        print(f"  → Does not exist — creating.")
        if not dry_run:
            addr = client.create("Address", ADDRESS_PAYLOAD)
            print(f"  ✓ Created: {addr.get('name')}")
        else:
            print("  [dry-run] Would POST create address.")


def delete_company(client: ERPClient, abbr: str) -> None:
    """Dev utility: remove a company by its abbreviation (finds by GET list)."""
    url  = f"{client.base}/api/resource/Company?filters=[[\"abbr\",\"=\",\"{abbr}\"]]&fields=[\"name\"]"
    resp = client.session.get(url)
    _raise_for_frappe(resp)
    results = resp.json().get("data", [])
    if not results:
        print(f"No company with abbr={abbr} found.")
        return
    name = results[0]["name"]
    print(f"Deleting Company: {name}")
    client.delete("Company", name)
    print("Deleted.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Provision Axina Group Inc. in ERPNext.")
    parser.add_argument("--dry-run",  action="store_true", help="Validate only, no writes.")
    parser.add_argument("--delete",   metavar="ABBR",      help="Delete company by abbr (dev only).")
    args = parser.parse_args()

    _validate_config(CONFIG)

    client = ERPClient(CONFIG["url"], CONFIG["api_key"], CONFIG["api_secret"])

    print(f"ERP endpoint : {CONFIG['url']}")
    print(f"Dry run      : {args.dry_run}")
    print("\n[auth] Verifying credentials...")
    if not client.ping():
        print("[ERROR] Authentication failed. Check AXERP_API_KEY and AXERP_API_SECRET.")
        sys.exit(1)

    if args.delete:
        delete_company(client, args.delete)
        return

    try:
        provision_company(client, dry_run=args.dry_run)
        print("\n✅ Done.\n")
    except RuntimeError as exc:
        print(f"\n[ERROR] {exc}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
