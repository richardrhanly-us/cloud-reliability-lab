from fastapi import FastAPI
from fastapi.responses import JSONResponse
from datetime import datetime, timezone
import os
import socket

import psycopg


app = FastAPI(title="Cloud Reliability Lab")

START_TIME = datetime.now(timezone.utc)

CONFIG_PATH = "config/app.conf"

with open(CONFIG_PATH, "r") as config_file:
    APP_CONFIG = config_file.read().strip()


@app.get("/")
def root():
    return {
        "service": "cloud-reliability-lab",
        "status": "running",
        "message": "FastAPI reliability lab is online",
        "config": APP_CONFIG
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "hostname": socket.gethostname(),
        "started_at": START_TIME.isoformat(),
        "checked_at": datetime.now(timezone.utc).isoformat()
    }


@app.get("/ready")
def ready():
    try:
        with psycopg.connect(
            host=os.getenv("DB_HOST", "127.0.0.1"),
            port=os.getenv("DB_PORT", "5432"),
            dbname=os.getenv("DB_NAME", "cloudlab"),
            user=os.getenv("DB_USER", "cloudlab"),
            password=os.getenv("DB_PASSWORD"),
            connect_timeout=2,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()

        return {
            "status": "ready",
            "database": "connected"
        }

    except Exception as exc:
        return JSONResponse(
            status_code=503,
            content={
                "status": "not_ready",
                "database": "unavailable",
                "error": str(exc)
            }
        )


@app.get("/version")
def version():
    return {
        "service": "cloud-reliability-lab",
        "version": os.getenv("APP_VERSION", "0.1.0")
    }
