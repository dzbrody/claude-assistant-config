output "deployment_summary" {
  description = "Summary of deployed resources"
  value = <<-EOT

    ==============================================
      OpenProject Deployment Complete
    ==============================================

      Web UI:   https://${var.domain_name}
      SSH:      ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_eip.openproject.public_ip}

    Connect MCP to Claude CLI (via SSM tunnel):
      1. terraform output instance_id
      2. ../../scripts/ssm-mcp-tunnel.sh <instance-id>
      3. claude mcp add --transport sse openproject http://localhost:39127/sse

    ==============================================
  EOT
}