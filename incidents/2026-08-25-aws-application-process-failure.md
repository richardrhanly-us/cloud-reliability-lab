# Incident Report: AWS Application Process Failure

## Date

2026-08-25

## Environment

AWS Cloud Reliability Lab

```text
Amazon EC2
Amazon Linux 2023
FastAPI / Uvicorn
systemd
nginx
AWS Systems Manager
CloudWatch Agent
CloudWatch Logs
```

EC2 instance:

```text
i-08b19aebb655bcf36
```

## Scenario

A controlled application process failure was introduced on the AWS EC2 application server to validate automatic service recovery.

The Uvicorn process managed by systemd was intentionally terminated with `SIGKILL`.

The EC2 instance, nginx reverse proxy, IAM configuration, networking, and Terraform-managed infrastructure were left unchanged.

## Baseline

Before the failure:

```text
MainPID=26969
NRestarts=0
ActiveState=active
SubState=running
```

The application was healthy when tested directly:

```bash
curl http://127.0.0.1:8000/health
```

and through nginx:

```bash
curl http://127.0.0.1/health
```

Both returned:

```text
status: ok
```

## Failure Injection

The application process was terminated using:

```bash
sudo kill -9 26969
```

Immediately after termination, systemd reported:

```text
MainPID=0
NRestarts=0
ActiveState=activating
SubState=auto-restart
```

This showed that systemd detected the failure and entered its configured automatic restart workflow.

## Recovery

After the restart delay, systemd reported:

```text
MainPID=33465
NRestarts=1
ActiveState=active
SubState=running
```

The original process ID:

```text
26969
```

was replaced by:

```text
33465
```

No manual service restart was required.

## Validation

The recovered application was tested directly:

```bash
curl http://127.0.0.1:8000/health
```

and through nginx:

```bash
curl http://127.0.0.1/health
```

Both returned successful health responses.

## systemd Evidence

The system journal recorded:

```text
cloud-reliability-lab.service: Main process exited, code=killed, status=9/KILL
cloud-reliability-lab.service: Failed with result 'signal'
cloud-reliability-lab.service: Scheduled restart job, restart counter is at 1
```

This confirmed that systemd detected the process failure and automatically scheduled recovery.

## CloudWatch Evidence

The application CloudWatch log stream recorded both Uvicorn startup events:

```text
INFO: Started server process [26969]
INFO: Started server process [33465]
```

This confirms that centralized application logging continued across the process restart.

The current CloudWatch configuration captures application and nginx log files. The systemd journal itself is not currently forwarded to CloudWatch, so the `SIGKILL` and automatic restart messages were validated locally through `journalctl`.

## Root Cause

Intentional controlled process termination using `SIGKILL`.

This was not an infrastructure, nginx, networking, IAM, or EC2 failure.

## Impact

The FastAPI application process was temporarily unavailable during the systemd restart delay.

The EC2 instance and nginx remained available.

The application recovered automatically without administrator intervention.

## Resolution

No manual remediation was required.

systemd automatically restarted the application according to the service configuration.

## Lessons Learned

- systemd automatic restart works correctly on the AWS-hosted deployment.
- the application can recover from an unexpected Uvicorn process termination without manual intervention.
- nginx remains isolated from the application process lifecycle.
- AWS Systems Manager provides sufficient administrative access for troubleshooting without exposing SSH.
- CloudWatch successfully captures application startup events before and after recovery.
- systemd journal events are not yet centralized in CloudWatch and represent a potential monitoring improvement.

## Follow-Up Improvements

- Forward systemd/journald service events to centralized monitoring.
- Add CloudWatch alerting for application availability, not only EC2 CPU utilization.
- Test a failure that affects nginx independently from FastAPI.
- Test security-group or network-path failure.
- Add automated recovery validation.