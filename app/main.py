from fastapi import FastAPI
from datetime import datetime, timezone
import socket
import os

app = FastAPI(title="Cloud Reliability Lab")

START_TIME = datetime.now(timezone.utc)


@app.get("/")
def root():
    return {
        "service": "cloud-reliability-lab",
        "status": "running",
        "message": "FastAPI reliability lab is online"
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "hostname": socket.gethostname(),
        "started_at": START_TIME.isoformat(),
        "checked_at": datetime.now(timezone.utc).isoformat()
    }


@app.get("/version")
def version():
    return {
        "service": "cloud-reliability-lab",
        "version": os.getenv("APP_VERSION", "0.1.0")
    }
