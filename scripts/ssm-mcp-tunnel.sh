#!/bin/bash
# ssm-mcp-tunnel.sh — Create SSM tunnel to OpenProject MCP server
# Prerequisites: AWS CLI installed and configured, SSM Agent on target EC2
# Usage: ./scripts/ssm-mcp-tunnel.sh <ec2-instance-id>

set -e

INSTANCE_ID="$1"

if [ -z "$INSTANCE_ID" ]; then
  echo "Usage: ./scripts/ssm-mcp-tunnel.sh <ec2-instance-id>"
  echo ""
  echo "Get the instance ID from Terraform output:"
  echo "  cd infrastructure/terraform && terraform output instance_id"
  echo ""
  exit 1
fi

echo "============================================"
echo "  OpenProject MCP — SSM Tunnel"
echo "============================================"
echo ""
echo "  Instance:  $INSTANCE_ID"
echo "  Tunnel:    localhost:39128 -> EC2:39128"
echo ""
echo "  Keep this terminal open."
echo "  Use Ctrl+C to close the tunnel."
echo ""
echo "  Then in another terminal:"
echo "    claude mcp add --transport sse openproject http://localhost:39128/sse"
echo ""
echo "============================================"
echo ""

aws ssm start-session \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["39128"],"localPortNumber":["39128"]}' \
  --profile claude-assistant
