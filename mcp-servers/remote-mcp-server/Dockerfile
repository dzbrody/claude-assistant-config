FROM python:3.13-slim-bookworm

WORKDIR /app

RUN pip install --no-cache-dir \
    "mcp[cli]==1.27.2" \
    "uvicorn==0.49.0" \
    "httpx==0.28.1" \
    "boto3==1.43.25" \
    "starlette==1.2.1"

COPY server.py /app/server.py

RUN useradd -m mcp && chown -R mcp:mcp /app
USER mcp

EXPOSE 39128

CMD ["python", "server.py"]
