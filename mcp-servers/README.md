# MCP Servers

MCP servers extend Claude with tools for email, calendar, messaging, files, and browser automation.

## Installed Servers

| Server | Purpose | Transport |
|--------|---------|-----------|
| `google-workspace` | Gmail, Google Calendar, Drive, Tasks | stdio |
| `whatsapp` | WhatsApp messaging (outbound) | stdio |
| `document-loader` | Read Office/PDF files | stdio |
| `filesystem` | Controlled file access — see paths below | stdio |
| `playwright` | Browser automation | stdio |
| `office365-local` | Control Word/Excel/PowerPoint desktop apps | stdio (manual) |
| `openproject` | OpenProject project management at projects.axinagroup.com | stdio |

## Filesystem Paths

The `filesystem` server is granted access to these directories:

### Personal
| Path | Notes |
|------|-------|
| `~/Documents` | Personal documents |
| `~/Downloads` | General staging |
| `~/Desktop` | Desktop staging |

### Google Drive — db@xgccorp.com (`~/Library/CloudStorage/GoogleDrive-db@xgccorp.com/`)
| Path | Org | Notes |
|------|-----|-------|
| `My Drive` | XGC | db@xgccorp.com personal drive |
| `Shared drives/XGC` | XGC | Main XGC company files |
| `Shared drives/AXINAGRP` | AXINA | AXINA group files |
| `Shared drives/CCCL` | XGC | CCCL shared drive |
| `Shared drives/Development` | XGC | Development shared drive |
| `Shared drives/dnloadfiles` | XGC | Download staging |
| `Shared drives/XGC-WORKING_FILES` | XGC | Active working files |

### Google Drive — Personal Accounts
| Path | Account | Notes |
|------|---------|-------|
| `GoogleDrive-daniel@brody.ca/My Drive` | daniel@brody.ca | Personal / 4ward.earth work |
| `GoogleDrive-dzbrody99@gmail.com/My Drive` | dzbrody99@gmail.com | Personal Gmail drive |

### OneDrive
| Path | Notes |
|------|-------|
| `OneDrive-Personal` | Personal OneDrive |
| `~/OneDrive` | Synced org / Microsoft Teams files |

## Install All

```bash
bash install-all.sh
```

## Add a Server

```bash
# npm package
claude mcp add --transport stdio <name> -- npx -y <package-name>

# Python script (via uv)
claude mcp add --transport stdio <name> -- uv --directory /path/to/project run main.py

# HTTP remote server
claude mcp add --transport http <name> <url> --header "Authorization: Bearer TOKEN"
```

## Remove a Server

```bash
claude mcp remove <name>
```

## List All Servers

```bash
claude mcp list
```

## OpenProject MCP

**Server:** [AndyEverything/openproject-mcp-server](https://github.com/AndyEverything/openproject-mcp-server)  
**Cloned to:** `~/.claude-assistant/mcp-servers/openproject-mcp/`  
**Script:** `openproject-mcp-fastmcp.py`  
**Transport:** stdio (runs locally on Mac, connects to remote OpenProject via HTTPS)

### Setup

```bash
cd ~/.claude-assistant/mcp-servers
git clone https://github.com/AndyEverything/openproject-mcp-server.git openproject-mcp
cd openproject-mcp
uv sync
cp env_example.txt .env
# Edit .env — add your API key (never commit this file)
```

### Generate API Key

1. Log into https://projects.axinagroup.com
2. Avatar → **My account** → **Access tokens** → **+ Add**
3. Name: "Claude MCP", copy the 40-character token
4. Paste into `~/.claude-assistant/mcp-servers/openproject-mcp/.env`

### Register with Claude CLI

```bash
claude mcp add --transport stdio openproject \
  --env OPENPROJECT_URL=https://projects.axinagroup.com \
  --env OPENPROJECT_API_KEY=<your-40-char-token> \
  -- uv --directory ~/.claude-assistant/mcp-servers/openproject-mcp run openproject-mcp-fastmcp.py
```

### Claude Desktop Config

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "openproject": {
      "command": "/Users/dzbrody/.local/bin/uv",
      "args": [
        "--directory",
        "/Users/dzbrody/.claude-assistant/mcp-servers/openproject-mcp",
        "run",
        "openproject-mcp-fastmcp.py"
      ],
      "env": {
        "OPENPROJECT_URL": "https://projects.axinagroup.com",
        "OPENPROJECT_API_KEY": "<your-40-char-token>"
      }
    }
  }
}
```

### Verify

```bash
claude mcp list
# openproject: ... - ✓ Connected
```

Then in a Claude session: *"List my OpenProject projects"*

## Planned / Not Yet Configured

| Server | Notes |
|--------|-------|
| `github` | For XGC and AXINA project/issue tracking |
| `notion` | Requires Notion API key and MCP server setup |
