# Incident Report: Application Crash and Automatic Recovery

## Summary

A controlled application failure was triggered against the Cloud Reliability Lab FastAPI service to test systemd automatic recovery behavior.

The service was intentionally stopped using `systemctl kill`. systemd detected the stopped process and automatically restarted the service based on the configured restart policy.

## Date

2026-08-09

## Environment

| Component | Value |
|---|---|
| Host | `hp-homelab` |
| Application | Cloud Reliability Lab FastAPI service |
| Process manager | systemd |
| Reverse proxy | nginx |
| Application port | `127.0.0.1:8000` |
| Public LAN endpoint | `http://192.168.1.216/health` |

## Impact

The application process was terminated intentionally as part of a controlled test.

Impact was minimal because systemd automatically restarted the service within a few seconds.

## Detection

The failure and recovery were observed using:

- `systemctl status cloud-reliability-lab`
- `journalctl -u cloud-reliability-lab`
- `/health` endpoint checks
- nginx access logs

## Timeline

| Time UTC | Event |
|---|---|
| 21:13:13 | FastAPI service started under systemd |
| 21:13:42 | Local health check returned HTTP 200 |
| 21:15:51 | Service was intentionally killed |
| 21:15:56 | systemd scheduled and started automatic restart |
| 21:15:57 | Uvicorn started successfully |
| 21:16:07 | Health check returned HTTP 200 after recovery |
| 21:18:52 | Health check through nginx returned HTTP 200 |
| 21:19:03 | Windows client reached `/health` through nginx |

## Root Cause

The service was intentionally terminated using:

```bash
sudo systemctl kill cloud-reliability-lab
