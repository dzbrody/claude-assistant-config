# Transcribe Audio from S3 or Google Drive / Meet

Transcribe an audio or video file using the `transcribe_s3_audio` tool on the EC2 MCP server. Accepts either an S3 key or a Google Drive / Google Meet recording URL.

## Source Detection

Inspect the argument provided by the user:

- **Google Drive / Meet URL** — matches `drive.google.com` or `meet.google.com` → follow **Drive path** below.
- **S3 key or "latest"** → follow **S3 path** below.
- **No argument** → ask: "Paste a Google Drive / Meet URL, an S3 key, or type 'latest'."

---

## Drive Path (Google Drive or Meet recording link)

1. **Extract the file ID** from the URL using the pattern `drive.google.com/file/d/([A-Za-z0-9_-]+)`. For Meet recording links that redirect through calendar or other Google products, follow the redirect text or ask the user to copy the direct Drive share link.
2. **Get file metadata**: call `mcp__google-workspace__get_file` with the extracted file ID to retrieve `name` and `mimeType`.
3. **Download the file**: call `mcp__google-workspace__get_file_content` with the file ID. Save the binary to local temp via `mcp__filesystem__write_file` at path `/tmp/{name}` (preserve original filename and extension).
4. **Upload to S3**: run via Bash — `aws s3 cp /tmp/{name} s3://axina-openproject-files/meet-recordings/{name}` — and confirm the upload succeeded.
5. **Clean up**: `rm /tmp/{name}` after a successful upload.
6. **Set S3 key** to `meet-recordings/{name}` and proceed to **Transcribe** step below.

---

## S3 Path

1. Ask: "What is the S3 key for the audio file? (bucket defaults to `axina-openproject-files`)"
   - If the user says "latest" or "newest", call `mcp__openproject-remote__search_s3_objects` with query `.m4a` (then `.mp3`, `.wav`) to find the most recent file by `last_modified`.

---

## Transcribe

Call `mcp__openproject-remote__transcribe_s3_audio` with:
- `bucket`: `axina-openproject-files` (or as specified)
- `key`: the S3 key from whichever path was taken above
- `model_size`: `tiny` (default) — ask if the user wants `base` for better accuracy

Display the transcript with timestamps.

## Post-Transcription

Ask: "Create OpenProject tasks from the action items in this transcript? [y/N]"
- If `y`: extract action items, apply the Project Routing Guide and Task Assignment Rules from `morning-briefing.md` to route each to the correct project, and call `mcp__openproject-remote__create_work_package` for each. List the created task IDs.
