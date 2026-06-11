# Transcribe Audio from S3

Transcribe an audio file stored in S3 using the `transcribe_s3_audio` tool on the EC2 MCP server.

## Steps

1. Ask: "What is the S3 key for the audio file? (bucket defaults to `axina-openproject-files`)"
   - If the user says "latest" or "newest", call `search_s3_objects` with query `.m4a` (then `.mp3`, `.wav`) to find the most recent file by `last_modified`.
2. Call `mcp__openproject-remote__transcribe_s3_audio` with:
   - `bucket`: `axina-openproject-files` (or as specified)
   - `key`: the file path provided or found
   - `model_size`: `tiny` (default) — ask the user if they want `base` for better accuracy
3. Display the transcript with timestamps.
4. Ask: "Create OpenProject tasks from the action items in this transcript? [y/N]"
   - If `y`: extract action items, use the Project Routing Guide in `morning-briefing.md` to route each to the correct project, and call `create_work_package` for each. List the created task IDs.
