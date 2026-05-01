# OpenProject Infrastructure

OpenProject + MCP Server on EC2 with Docker Compose, served at `projects.axinagroup.com`.

## Architecture

- **EC2 Instance**: t3.large (2 vCPU, 8GB RAM), Amazon Linux 2023
- **Elastic IP**: Static IP for consistent DNS and MCP connection
- **Docker Containers**:
  - `openproject/openproject:17` — OpenProject application (port 8080)
  - `postgres:14` — Database
  - `memcached` — Rails cache
  - `nginx` — Reverse proxy + SSL termination
  - `certbot` — Let's Encrypt auto-renewal
- **EBS Volumes**:
  - `/dev/xvda` (30GB gp3) — Root
  - `/dev/xvdf` (100GB gp3) — Persistent data (survives instance replacement)

## Storage

- **Database**: PostgreSQL (containerized, data on `/data/openproject/pgdata`)
- **Attachments**: S3 bucket `axina-openproject-files` in us-east-1
  - SSE-S3 encryption enabled
  - Versioning enabled (90-day retention for old versions)
  - CORS configured for `projects.axinagroup.com`
  - No public access
  - Access granted to EC2 via IAM role (no hardcoded credentials)
- **EBS**: 100GB gp3 for Docker volumes and container data

## Quick Deploy

### Prerequisites
- AWS CLI configured with `us-east-1`
- Terraform installed (`brew install terraform`)
- Your IP: 99.239.58.91 (IPv4), 2001:4860:7:704::f8 (IPv6)
- SSH key: `aws-key-xgccloudcom`

### 1. Deploy Infrastructure
```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### 2. Get outputs
```bash
terraform output public_ip
terraform output instance_id
```

### 3. SSH into the server (initial setup)
```bash
ssh -i ~/.ssh/aws-key-xgccloudcom.pem ec2-user@<public_ip>
```

### 4. Add OpenProject API key
After OpenProject is running, generate an API key in the web UI (Admin → API → Generate), then:
```bash
echo "OPENPROJECT_API_KEY=<your-key>" >> /opt/openproject/.env
docker-compose -f /opt/openproject/docker-compose-mcp.yml up -d
```

### 5. IAM role
Terraform creates `axina-openproject-role` with `AmazonSSMManagedInstanceCore` attached and wires it to the EC2 instance automatically. No manual IAM steps needed.

### 6. Connect Claude CLI (via SSM Tunnel)

The MCP server is NOT publicly accessible. Port 39127 binds to `127.0.0.1` on the EC2 instance only.

```bash
# 1. Get the instance ID
cd infrastructure/terraform
terraform output instance_id

# 2. Start the SSM tunnel (keep this terminal open)
../../scripts/ssm-mcp-tunnel.sh <instance-id>

# 3. In another terminal, connect Claude
claude mcp add --transport sse openproject http://localhost:39127/sse
```

To close: Ctrl+C the tunnel terminal. The MCP connection in Claude will drop until you reconnect.

**Troubleshooting S3**: If attachments fail to upload, verify:
1. EC2 can reach S3: `aws s3 ls s3://axina-openproject-files/` from the server
2. CORS is configured: AWS Console → S3 → bucket → Permissions → CORS
3. IAM role policy is attached: AWS Console → IAM → `axina-openproject-role` → Permissions

### 6. Connect Claude CLI (local MCP server)

The MCP server runs locally on your Mac and connects to OpenProject over HTTPS — no SSM tunnel needed.

```bash
cd ~/.claude-assistant/mcp-servers
git clone https://github.com/AndyEverything/openproject-mcp-server.git openproject-mcp
cd openproject-mcp && uv sync
cp env_example.txt .env   # edit .env with your API key

claude mcp add --transport stdio openproject \
  --env OPENPROJECT_URL=https://projects.axinagroup.com \
  --env OPENPROJECT_API_KEY=<your-token> \
  -- uv --directory ~/.claude-assistant/mcp-servers/openproject-mcp run openproject-mcp-fastmcp.py
```

See `mcp-servers/README.md` for full setup including API key generation and Claude Desktop config.

## Email (SES SMTP)

- **Provider**: AWS SES us-east-1
- **SMTP endpoint**: `email-smtp.us-east-1.amazonaws.com:587`
- **Verified domain**: `axinagroup.com`
- **From address**: `no-reply@axinagroup.com`
- **Auth**: STARTTLS + login (SMTP credentials, not IAM keys)

### Generate SES SMTP Credentials

SMTP credentials are **different** from IAM access keys — the password is derived via a signing algorithm.

1. AWS Console → SES → **SMTP settings** → **Create SMTP credentials**
2. IAM creates a user automatically — save the SMTP username and password shown (only shown once)
3. Add to `/opt/openproject/.env` on the server:
   ```
   SMTP_USERNAME=<smtp-user>
   SMTP_PASSWORD=<smtp-password>
   ```

### Apply to Running Server

```bash
aws ssm start-session --target i-03a1a1d683b542d47
cd /opt/openproject
# Edit .env and add SMTP_USERNAME and SMTP_PASSWORD
docker-compose up -d openproject
# Test: Admin → Emails → Send test email
```

### Sandbox Mode

SES starts in sandbox — can only send to verified addresses.

- Check: AWS Console → SES → Account dashboard → Sending restrictions
- To test: verify a recipient address under SES → Verified identities
- For production sending: request production access via SES → Account dashboard

### Troubleshooting

| Symptom | Check |
|---------|-------|
| `535 Authentication failed` | Wrong SMTP password (must be SES-derived, not IAM secret) |
| Emails not received | SES sandbox mode — verify recipient address first |
| `STARTTLS` error | Confirm port 587, `ENABLE__STARTTLS__AUTO: "true"` |

## Backup

- **Schedule**: Daily at 2:00 AM Eastern (07:00 UTC) via systemd timer
- **Destination**: `s3://axina-openproject-files/backups/YYYY/MM/DD/`
- **Retention**: 7 days STANDARD → 90 days STANDARD_IA → 365 days GLACIER
- **Script**: `/opt/openproject/scripts/backup-to-s3.sh`
- **Credentials**: `/opt/openproject/.env.backup` (chmod 600)
- **API user**: `backup-bot` (admin, ID 11)
- **API token**: stored in `.env.backup` on server

### One-Time Setup: Generate Backup Token

1. Log in as admin → **Administration** → **Backup**
2. Click **+ Backup token** → type `create` → enter password
3. **Copy the token immediately** (shown only once)
4. Add to server:
   ```bash
   aws ssm start-session --target i-03a1a1d683b542d47
   echo "OPENPROJECT_BACKUP_TOKEN=<paste-token>" >> /opt/openproject/.env.backup
   ```

### Manual Backup
```bash
aws ssm start-session --target i-03a1a1d683b542d47
/opt/openproject/scripts/backup-to-s3.sh
```

### Verify
```bash
aws s3 ls s3://axina-openproject-files/backups/ --recursive --human-readable
systemctl status openproject-backup.timer
```

### Restore
```bash
aws s3 cp s3://axina-openproject-files/backups/YYYY/MM/DD/<file>.zip /tmp/
aws ssm start-session --target i-03a1a1d683b542d47
docker exec -it openproject-app bundle exec rake backup:restore BACKUP=/tmp/<file>.zip
```

## GitHub Integration

- **OpenProject user**: `github-integration` (ID: 10) — makes automated PR comments
- **Role**: `GitHub Integration` — `view_work_packages` + `add_work_package_notes`
- **Webhook token**: `opapi-7c7a4e7f650ead6e7e332042a270d8a250b556ea7b3b065358843f0c3c32b0ba`
- **Webhook URL**: `https://projects.axinagroup.com/webhooks/github?key=opapi-7c7a4e7f650ead6e7e332042a270d8a250b556ea7b3b065358843f0c3c32b0ba`
- **GitHub module enabled**: Demo project, Scrum project

### Add a Webhook to a GitHub Repo

1. GitHub repo → **Settings** → **Webhooks** → **Add webhook**
2. Payload URL: `https://projects.axinagroup.com/webhooks/github?key=opapi-7c7a4e7f650ead6e7e332042a270d8a250b556ea7b3b065358843f0c3c32b0ba`
3. Content type: `application/json`
4. Events: **Send me everything**
5. Active: ✓ → **Add webhook**

GitHub sends a `ping` immediately — check logs: `docker logs openproject-app --tail 20 | grep -i github`

### Link a PR to a Work Package

In the PR description include: `OP#<work-package-id>` (e.g. `OP#5`)
The work package's **GitHub tab** will then show the PR and its status.

### Add a New Project

```bash
aws ssm start-session --target i-03a1a1d683b542d47
docker exec openproject-app bundle exec rails runner "
  user = User.find_by(login: 'github-integration')
  role = Role.find_by(name: 'GitHub Integration')
  p = Project.find_by(identifier: 'your-project-id')
  Member.create!(project_id: p.id, user_id: user.id, roles: [role])
  p.enabled_modules.create!(name: 'github')
"
```

## Remote MCP Server

A FastAPI SSE server (`openproject-mcp-server` Docker container) runs alongside OpenProject and exposes OpenProject + S3 tools to Claude Desktop and Claude Mobile from anywhere.

### Architecture

```
Claude Desktop / Mobile
        |
        | HTTPS (X-MCP-Key header)
        v
nginx (/mcp location) → openproject-mcp-server:39128
        |                       |
        |              OpenProject API (internal)
        |              AWS S3 (via EC2 IAM role)
```

### Tools Available

| Tool | Description |
|------|-------------|
| `list_projects` | List all OpenProject projects |
| `get_project` | Get project details |
| `create_work_package` | Create a task/feature/bug in a project |
| `list_s3_buckets` | List accessible S3 buckets |
| `list_s3_objects` | List objects in a bucket |
| `get_s3_object` | Read a file from S3 |
| `search_s3_objects` | Search files by name pattern |

### First-Time Setup (on the running EC2)

```bash
aws ssm start-session --target i-03a1a1d683b542d47
cd /opt/openproject

# 1. Generate MCP API key
MCP_API_KEY=$(openssl rand -hex 32)
echo "Save this key — you'll need it for all clients:"
echo $MCP_API_KEY

# 2. Get an OpenProject admin API token
#    → OpenProject UI: My Account → Access tokens → + API token

# 3. Add secrets to .env
echo "MCP_API_KEY=$MCP_API_KEY" >> .env
echo "OPENPROJECT_ADMIN_API_KEY=<paste-token>" >> .env
chmod 600 .env

# 4. Write MCP server files (if not already done by user-data)
mkdir -p /data/mcp-server
# Copy server.py and Dockerfile from this repo, or they were written by user-data.sh

# 5. Build and start
docker-compose up -d --build mcp-server

# 6. Verify
curl https://projects.axinagroup.com/mcp/health \
  -H "X-MCP-Key: $MCP_API_KEY"
```

### Connect Claude CLI (Remote)

```bash
claude mcp add --transport sse --scope user openproject-remote \
  https://projects.axinagroup.com/mcp/sse \
  --header "X-MCP-Key: <your-mcp-api-key>"
```

### Connect Claude Mobile

1. Open Claude mobile app
2. Settings → MCP Servers → Add Server
3. URL: `https://projects.axinagroup.com/mcp/sse`
4. Header: `X-MCP-Key: <your-mcp-api-key>`
5. Name: `AXINA Group`

### Store Key in macOS Keychain

```bash
security add-generic-password \
  -a "$USER" \
  -s "openproject-mcp-api-key" \
  -w "<your-mcp-api-key>"

# Retrieve later:
security find-generic-password -s "openproject-mcp-api-key" -w
```

## Security Notes

- Port 39128 (MCP server) binds to `127.0.0.1` only — not reachable directly from internet
- Access is via nginx `/mcp` location, protected by `X-MCP-Key` header check
- The MCP API key is separate from the OpenProject API key
- S3 access uses the EC2 IAM role — no AWS credentials stored in the container