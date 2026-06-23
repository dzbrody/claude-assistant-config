#!/bin/bash
# deploy-github-integration.sh
#
# Deploys the custom OpenProject image (with GitHub Integration plugin) to EC2.
# Runs from your local Mac — uses SSM to execute commands on EC2 (no SSH needed).
#
# Usage:
#   bash deploy-github-integration.sh <EC2_INSTANCE_ID>
#   bash deploy-github-integration.sh i-0abc123def456789
#
# Prerequisites:
#   aws configure --profile claude-assistant  (already done)
#   Instance must have SSM agent running (it does — Amazon Linux 2023 default)

set -e

INSTANCE_ID="${1}"
PROFILE="claude-assistant"
REGION="us-east-1"

if [ -z "$INSTANCE_ID" ]; then
  echo "Usage: $0 <EC2_INSTANCE_ID>"
  echo ""
  echo "Find your instance ID:"
  echo "  aws ec2 describe-instances --profile $PROFILE --region $REGION \\"
  echo "    --filters 'Name=tag:Name,Values=openproject' \\"
  echo "    --query 'Reservations[].Instances[].InstanceId' --output text"
  exit 1
fi

echo "=== Step 1: Upload Dockerfile to S3 ==="
aws s3 cp "$(dirname "$0")/Dockerfile.openproject" \
  s3://ctorescues-openproject-files/deploy/Dockerfile.openproject \
  --profile "$PROFILE" --region "$REGION"
echo "✓ Dockerfile uploaded"

echo ""
echo "=== Step 2: Run build + deploy on EC2 via SSM ==="
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --parameters 'commands=[
    "set -e",
    "echo \"--- Pulling Dockerfile from S3 ---\"",
    "aws s3 cp s3://ctorescues-openproject-files/deploy/Dockerfile.openproject /opt/openproject/Dockerfile.openproject",
    "echo \"--- Building custom OpenProject image ---\"",
    "cd /opt/openproject",
    "docker build -f Dockerfile.openproject -t ctorescues-openproject:latest . 2>&1 | tail -20",
    "echo \"--- Stopping old openproject-app container ---\"",
    "docker compose stop openproject || docker stop openproject-app || true",
    "echo \"--- Starting new container ---\"",
    "docker compose up -d openproject",
    "echo \"--- Waiting 30s for startup ---\"",
    "sleep 30",
    "echo \"--- Running migrations ---\"",
    "docker compose exec -T openproject bundle exec rake db:migrate 2>&1 | tail -10",
    "echo \"--- Restarting to pick up plugin routes ---\"",
    "docker compose restart openproject",
    "sleep 15",
    "echo \"--- Health check ---\"",
    "curl -sf http://localhost:8080/health || echo WARNING: health check failed",
    "echo \"--- Done ---\""
  ]' \
  --query 'Command.CommandId' \
  --output text)

echo "SSM Command ID: $COMMAND_ID"
echo "Waiting for command to complete (this takes 3-5 minutes for the Docker build)..."

# Poll until done
for i in $(seq 1 60); do
  sleep 10
  STATUS=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'Status' --output text 2>/dev/null || echo "Pending")
  echo "  [$((i*10))s] Status: $STATUS"
  if [[ "$STATUS" == "Success" || "$STATUS" == "Failed" || "$STATUS" == "Cancelled" ]]; then
    break
  fi
done

echo ""
echo "=== Step 3: Show output ==="
aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'StandardOutputContent' \
  --output text

if [ "$STATUS" == "Success" ]; then
  echo ""
  echo "============================================"
  echo "  Deploy complete!"
  echo "============================================"
  echo ""
  echo "=== Step 4: Configure GitHub webhook ==="
  echo ""
  echo "1. Go to: https://github.com/dzbrody/claude-assistant-config/settings/hooks/new"
  echo ""
  echo "2. Payload URL:  https://projects.ctorescues.com/webhooks/github"
  echo "   Content type: application/json"
  echo "   Secret:       generate with: openssl rand -hex 32"
  echo "   Events:       'Pull requests' + 'Pull request reviews' + 'Pushes'"
  echo ""
  echo "3. Save the secret, then add it to OpenProject:"
  echo "   https://projects.ctorescues.com/admin/settings/plugin/openproject_github_integration"
  echo ""
  echo "4. Test by opening a PR with 'Closes OP#164' in the description."
  echo "   It will appear on work package #164 under the GitHub tab."
else
  echo ""
  echo "Deploy FAILED (status: $STATUS). Check output above."
  echo "To debug: aws ssm start-session --target $INSTANCE_ID --profile $PROFILE --region $REGION"
fi
