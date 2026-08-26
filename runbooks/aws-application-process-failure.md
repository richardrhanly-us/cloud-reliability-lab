# Runbook: AWS Application Process Failure

## Scenario

The FastAPI/Uvicorn process on the AWS EC2 application server exits unexpectedly while the EC2 instance, nginx reverse proxy, and network infrastructure remain available.

## Expected Behavior

The application is managed by systemd with automatic restart enabled.

If the Uvicorn process exits unexpectedly:

1. systemd should detect the failure.
2. The service should enter an automatic restart state.
3. systemd should start a new Uvicorn process.
4. The `/health` endpoint should recover without manual intervention.
5. Application startup events should appear in CloudWatch Logs.

## Environment

AWS application server:

```text
Amazon EC2
Amazon Linux 2023
systemd
nginx
FastAPI / Uvicorn
AWS Systems Manager Session Manager
CloudWatch Agent
CloudWatch Logs