MCP Servers
Installed Servers
Server	Purpose	Transport
google-workspace	Gmail, Calendar, Drive	stdio
whatsapp	WhatsApp messaging	stdio
office365-local	Control Word/Excel/PowerPoint desktop apps	stdio
document-loader	Read Office/PDF files	stdio
filesystem	Controlled file access to Documents/Downloads/Desktop	stdio
playwright	Browser automation	stdio
Adding a New Server
bash
# Stdio-based npm package
claude mcp add --transport stdio <name> -- npx -y <package-name>

# Stdio-based Python script
claude mcp add --transport stdio <name> -- /usr/local/bin/python3 /path/to/script.py

# HTTP-based remote server
claude mcp add --transport http <name> <url> --header "Authorization: Bearer TOKEN"
