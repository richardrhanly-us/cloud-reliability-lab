# Cloud Reliability Lab

Production-style Linux reliability lab built to practice systems administration, service monitoring, incident response, and SRE-style operations.

This project starts as a local homelab deployment and is designed to later expand into an AWS-based cloud reliability environment using EC2, CloudWatch, IAM, and Terraform.

## Overview

The Cloud Reliability Lab is a hands-on operations project that demonstrates how a small web service can be deployed, monitored, broken intentionally, recovered, and documented.

The current version runs on an Ubuntu homelab server and includes:

* FastAPI application
* systemd service management
* nginx reverse proxy
* health check endpoint
* journald logging
* nginx access/error logs
* automated service recovery
* operational runbooks
* incident reports
* validation screenshots

The purpose of the project is not just to deploy an application. The goal is to practice the operational work involved in keeping services reliable.

## Current Architecture

```text
Windows Client / Browser
        |
        v
nginx reverse proxy
Port 80
        |
        v
FastAPI / Uvicorn
127.0.0.1:8000
        |
        v
systemd service
cloud-reliability-lab.service
        |
        v
Ubuntu homelab server
hp-homelab
```

## Technology Stack

| Component     | Purpose                                    |
| ------------- | ------------------------------------------ |
| Ubuntu Server | Linux host environment                     |
| FastAPI       | Python web application framework           |
| Uvicorn       | ASGI application server                    |
| systemd       | Service management and automatic restart   |
| nginx         | Reverse proxy                              |
| journald      | Service logging                            |
| nginx logs    | HTTP access and error logging              |
| Uptime Kuma   | Health check monitoring                    |
| Git           | Version control and documentation tracking |

## Application Endpoints

| Endpoint   | Purpose                      |
| ---------- | ---------------------------- |
| `/`        | Basic application status     |
| `/health`  | Health check endpoint        |
| `/version` | Application version endpoint |

Example health check:

```bash
curl http://192.168.1.216/health
```

Example response:

```json
{
  "status": "ok",
  "hostname": "hp-homelab",
  "started_at": "2026-08-09T21:25:17.200127+00:00",
  "checked_at": "2026-08-09T21:25:48.571944+00:00"
}
```

## Service Management

The FastAPI application runs as a systemd service.

Service name:

```text
cloud-reliability-lab.service
```

Check service status:

```bash
sudo systemctl status cloud-reliability-lab
```

Restart the service:

```bash
sudo systemctl restart cloud-reliability-lab
```

View service logs:

```bash
journalctl -u cloud-reliability-lab -n 50 --no-pager
```

## Reverse Proxy

nginx listens on port `80` and forwards traffic to the FastAPI application running locally on `127.0.0.1:8000`.

This keeps Uvicorn bound to localhost while nginx handles client-facing HTTP traffic.

```text
Client request
      |
      v
nginx :80
      |
      v
Uvicorn 127.0.0.1:8000
```

nginx access log:

```bash
sudo tail -n 20 /var/log/nginx/cloud-reliability-lab-access.log
```

nginx error log:

```bash
sudo tail -n 20 /var/log/nginx/cloud-reliability-lab-error.log
```

## Reliability Features

Current reliability features include:

* Dedicated `/health` endpoint
* systemd-managed application process
* Automatic service restart after failure
* nginx reverse proxy
* Local and remote health check validation
* journald service logs
* nginx access and error logs
* Uptime Kuma monitoring
* Runbook documentation
* Incident report documentation
* Validation screenshots

## Validation Screenshots

### Windows Health Check Through nginx

![Windows Health Check](screenshots/validation/windows-health-check.png)

Windows PowerShell health check confirming that the FastAPI service is reachable from another machine through nginx on port `80` and returning HTTP `200`.

### systemd Automatic Recovery Test

![systemd Automatic Recovery](screenshots/validation/systemd-auto-recovery.png)

Controlled application crash test showing systemd moving the service into an automatic restart state after the FastAPI process was intentionally killed. The `/health` endpoint returned successfully after recovery.

### Service Logs with journalctl

![journalctl Service Logs](screenshots/validation/journalctl-service-logs.png)

`journalctl` output showing FastAPI service startup logs and a successful health check request through the systemd-managed service.

## Validated Failure Scenario

### Application Crash

A controlled application failure was triggered using:

```bash
sudo systemctl kill cloud-reliability-lab
```

systemd detected the stopped service and automatically restarted it.

Recovery was validated with:

```bash
sudo systemctl status cloud-reliability-lab
curl http://127.0.0.1:8000/health
curl http://127.0.0.1/health
curl http://192.168.1.216/health
```

This confirms that the application can recover automatically from a basic process failure.

## Monitoring

The application can be monitored with Uptime Kuma using the `/health` endpoint.

Recommended monitor:

| Setting               | Value                          |
| --------------------- | ------------------------------ |
| Monitor Type          | HTTP(s)                        |
| Friendly Name         | Cloud Reliability Lab - Health |
| URL                   | `http://192.168.1.216/health`  |
| Heartbeat Interval    | 60 seconds                     |
| Retries               | 2                              |
| Request Timeout       | 15 seconds                     |
| Accepted Status Codes | 200-299                        |

## Project Structure

```text
cloud-reliability-lab/
├── README.md
├── app/
│   └── main.py
├── docs/
├── incidents/
│   └── 2026-08-09-application-crash-recovery.md
├── nginx/
├── runbooks/
│   └── application-crash.md
├── scripts/
├── screenshots/
│   └── validation/
│       ├── journalctl-service-logs.png
│       ├── systemd-auto-recovery.png
│       └── windows-health-check.png
└── systemd/
```

## Skills Demonstrated

This project demonstrates practical experience with:

* Linux administration
* Python web service deployment
* FastAPI application structure
* systemd service management
* nginx reverse proxy configuration
* TCP/IP and HTTP troubleshooting
* Health check design
* Application logging
* journald log review
* nginx access/error log review
* Automated service recovery
* Incident response documentation
* Runbook creation
* Git-based project documentation
* SRE-style failure testing

## Runbooks

Operational runbooks are stored in the `runbooks/` directory.

Current runbook:

* `application-crash.md` — steps for detecting, investigating, and recovering from an application crash

Planned runbooks:

* nginx reverse proxy failure
* blocked network port
* high CPU usage
* disk exhaustion
* permission failure
* failed deployment
* DNS failure

## Incident Reports

Incident reports are stored in the `incidents/` directory.

Current incident report:

* `2026-08-09-application-crash-recovery.md`

The incident report documents a controlled application crash, systemd automatic recovery, validation steps, and lessons learned.

## Planned Failure Scenarios

The lab is designed to support controlled failure testing.

Planned scenarios include:

* Application crash
* High CPU usage
* Disk exhaustion
* Permission failure
* DNS failure
* Blocked network port
* Incorrect nginx reverse proxy configuration
* Failed deployment
* Service restart loop
* Broken health check endpoint

## Planned AWS Expansion

The local homelab version is intended to become the foundation for a future AWS deployment.

Planned AWS components:

| AWS Component     | Purpose                          |
| ----------------- | -------------------------------- |
| EC2               | Linux compute host               |
| Amazon Linux 2023 | Cloud server operating system    |
| Security Groups   | Network access control           |
| IAM Role          | Instance permissions             |
| CloudWatch Agent  | Metrics and logs                 |
| CloudWatch Alarms | Alerting                         |
| Terraform         | Infrastructure as Code           |
| S3                | Optional artifact or log storage |

Future AWS architecture:

```text
Internet
   |
   v
AWS Security Group
   |
   v
EC2 Instance
   |
   v
nginx :80
   |
   v
FastAPI / Uvicorn
127.0.0.1:8000
   |
   v
systemd
   |
   v
CloudWatch Logs and Metrics
```

## Future Improvements

Planned improvements include:

* Add Uptime Kuma screenshot documentation
* Add nginx configuration file to the repository
* Add systemd service file to the repository
* Add install/setup script
* Add deployment script
* Add failure simulation scripts
* Add CloudWatch-based monitoring in AWS
* Add Terraform configuration for EC2 deployment
* Add IAM role configuration
* Add CloudWatch alarms
* Add automated recovery examples
* Add more incident reports and runbooks
* Add architecture diagrams

## Security Notes

This lab is currently designed for local network use.

Current security practices:

* Uvicorn listens only on `127.0.0.1`
* nginx is the client-facing HTTP entry point
* Administrative access is limited to the local network
* SSH is not exposed directly to the public internet
* No secrets, private keys, or credentials should be committed to the repository
* Environment files and Python virtual environments should be excluded with `.gitignore`

## Status

Current status:

```text
Local homelab deployment: Working
FastAPI health endpoint: Working
systemd service: Working
Automatic restart: Validated
nginx reverse proxy: Working
Windows health check screenshot: Added
systemd recovery screenshot: Added
journalctl service log screenshot: Added
Application crash runbook: Created
Application crash incident report: Created
AWS deployment: Planned
```
