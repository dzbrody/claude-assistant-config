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

## Planned / Not Yet Configured

| Server | Notes |
|--------|-------|
| `github` | For XGC and AXINA project/issue tracking |
| `notion` | Requires Notion API key and MCP server setup |
| `openproject` | Deploy on AWS (`us-east-1`), then add MCP server |
