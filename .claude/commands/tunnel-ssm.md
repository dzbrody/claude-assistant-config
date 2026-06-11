# Open SSM Tunnel to EC2 MCP Server

Open a port-forward tunnel from localhost:39128 to the EC2 MCP server using AWS SSM.

## Steps

1. Get the instance ID:
```bash
cd ~/.claude-assistant/infrastructure/terraform && terraform output -raw instance_id
```

2. Open the tunnel (keep terminal open):
```bash
~/.claude-assistant/scripts/ssm-mcp-tunnel.sh <instance-id>
```

3. The MCP server will be available at `http://localhost:39128/mcp/sse`

Use this when the remote MCP connection drops or when you need to connect Claude CLI directly to the EC2 instance instead of via HTTPS.
