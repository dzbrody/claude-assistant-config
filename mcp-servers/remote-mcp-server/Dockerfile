FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    "mcp[cli]" \
    uvicorn \
    httpx \
    boto3 \
    starlette

COPY server.py /app/server.py

RUN useradd -m mcp && chown -R mcp:mcp /app
USER mcp

EXPOSE 39128

CMD ["python", "server.py"]
