# Copyright (c) 2026 Yom Shore Ventures LLC
# dba: CTO Rescues - https://ctorescues.com/
# Author: Daniel Brody (@dzbrody)
#
# Principal Place of Business:
# 8 The Green – Suite 12060
# Dover, Delaware 19901
# United States
#
# All rights reserved. Proprietary and confidential.

FROM python:3.12-slim-bookworm

WORKDIR /app

# ffmpeg required by faster-whisper for audio decoding
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    "mcp[cli]==1.27.2" \
    "uvicorn==0.49.0" \
    "httpx==0.28.1" \
    "boto3==1.43.25" \
    "starlette==1.2.1" \
    "faster-whisper==1.0.3"

COPY server.py /app/server.py

# Whisper model cache — writable by unprivileged user
RUN mkdir -p /app/.cache/whisper && chown -R 1000:1000 /app

RUN useradd -m mcp && chown -R mcp:mcp /app
USER mcp

# HuggingFace downloads go to container-local cache, not ~/.cache
ENV HF_HOME=/app/.cache/whisper

EXPOSE 39128

CMD ["python", "server.py"]
