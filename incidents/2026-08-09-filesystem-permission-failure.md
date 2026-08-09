# Incident: Filesystem Permission Failure

## Date

2026-08-09

## Scenario

A controlled filesystem permission failure was introduced into the Cloud Reliability Lab.

The FastAPI application depends on a local configuration file:

```text
config/app.conf
```

The file permissions were intentionally changed so that the systemd service account could no longer read the file.

The purpose of the exercise was to practice tracing a service startup failure back through systemd, application logs, and Linux filesystem permissions.

## Expected Architecture

```text
systemd
  |
  v
cloud-reliability-lab.service
  |
  v
runs as user: rhanly
  |
  v
FastAPI / Uvicorn
  |
  v
reads config/app.conf
```

## Baseline State

The systemd service runs as:

```text
User=rhanly
Group=rhanly
```

The Uvicorn process also runs as:

```text
rhanly:rhanly
```

The required configuration file initially had:

```text
-rw-rw-r--
```

permissions and was owned by:

```text
rhanly:rhanly
```

The application successfully read:

```text
environment=homelab
```

and returned it through the root endpoint.

## Failure Injection

The file permissions were intentionally removed with:

```bash
chmod 000 config/app.conf
```

The file permissions changed from:

```text
-rw-rw-r--
```

to:

```text
----------
```

The service was then restarted:

```bash
sudo systemctl restart cloud-reliability-lab
```

## Impact

The FastAPI application failed to start.

systemd reported:

```text
Active: activating (auto-restart) (Result: exit-code)
```

and:

```text
status=1/FAILURE
```

The backend was no longer reachable on port `8000`.

A direct request failed:

```bash
curl http://127.0.0.1:8000/
```

Result:

```text
Could not connect to server
```

Because the application failed during startup, requests through nginx would also fail.

## Detection

The failure was detected through:

- systemd service status
- failed direct HTTP connection
- repeated automatic restart attempts
- application traceback in `journalctl`

## Investigation

### 1. Check Service Status

```bash
sudo systemctl status cloud-reliability-lab --no-pager
```

The service showed:

```text
activating (auto-restart)
```

with:

```text
status=1/FAILURE
```

This confirmed that systemd was attempting to restart the service, but the process continued to exit.

### 2. Test the Backend Directly

```bash
curl http://127.0.0.1:8000/
```

Result:

```text
curl: (7) Failed to connect to 127.0.0.1 port 8000
```

This confirmed that Uvicorn was not successfully listening on the expected backend port.

### 3. Review Application Logs

```bash
journalctl -u cloud-reliability-lab -n 50 --no-pager
```

The traceback showed:

```text
with open(CONFIG_PATH, "r") as config_file:
PermissionError: [Errno 13] Permission denied: 'config/app.conf'
```

This identified the failing operation as a file read during application startup.

### 4. Inspect File Permissions

```bash
ls -l config/app.conf
```

Result:

```text
---------- 1 rhanly rhanly ... config/app.conf
```

This showed that no read, write, or execute permissions were present.

### 5. Inspect Detailed Metadata

```bash
stat config/app.conf
```

The important result was:

```text
Access: (0000/----------)
Uid: (1000/rhanly)
Gid: (1000/rhanly)
```

This confirmed that the file was still owned by the expected user and group, but the permission mode prevented access.

### 6. Confirm Service User

```bash
id rhanly
```

The service account identity was confirmed as:

```text
uid=1000(rhanly)
gid=1000(rhanly)
```

The failure was therefore not caused by an unexpected service account.

The correct account owned the file but still had no permission to read it.

## Evidence

Recommended screenshots:

```text
screenshots/incidents/filesystem-permission-failure/service-user-baseline.png
screenshots/incidents/filesystem-permission-failure/config-permissions-before-failure.png
screenshots/incidents/filesystem-permission-failure/config-dependency-working.png
screenshots/incidents/filesystem-permission-failure/service-failure-after-permission-change.png
screenshots/incidents/filesystem-permission-failure/journalctl-permission-denied.png
screenshots/incidents/filesystem-permission-failure/permission-root-cause-confirmed.png
screenshots/incidents/filesystem-permission-failure/permission-recovery-validated.png
```

## Failing Layer

```text
Linux Filesystem Permissions
```

The following components were not the root cause:

- nginx
- TCP networking
- systemd itself
- application routing
- service account identity

The application failed because the operating system denied access to a required file.

## Root Cause

The required configuration file:

```text
config/app.conf
```

had its permissions changed to:

```text
0000
```

The FastAPI service runs as:

```text
rhanly
```

Even though `rhanly` owned the file, the owner had no read permission.

Python therefore failed when attempting to execute:

```python
with open(CONFIG_PATH, "r") as config_file:
```

This produced:

```text
PermissionError: [Errno 13] Permission denied: 'config/app.conf'
```

Uvicorn exited during startup.

systemd then repeatedly attempted to restart the service, but automatic recovery could not succeed because the underlying permission problem remained.

## Resolution

The expected permissions were restored with:

```bash
chmod 664 config/app.conf
```

The file returned to:

```text
-rw-rw-r--
```

The service was then restarted:

```bash
sudo systemctl restart cloud-reliability-lab
```

## Recovery Validation

The service was verified with:

```bash
sudo systemctl status cloud-reliability-lab --no-pager
```

Expected result:

```text
active (running)
```

The FastAPI backend was tested directly:

```bash
curl http://127.0.0.1:8000/
```

Expected response included:

```json
"config":"environment=homelab"
```

The nginx health path was also tested:

```bash
curl http://127.0.0.1/health
```

The LAN-facing path was validated with:

```bash
curl http://192.168.1.216/health
```

All checks returned successfully after the permission repair.

## Troubleshooting Path

```text
Application unavailable
        |
        v
Check systemd service
        |
        v
Service exiting and auto-restarting
        |
        v
Test backend directly
        |
        v
Port 8000 unavailable
        |
        v
Check journalctl
        |
        v
PermissionError on config/app.conf
        |
        v
Inspect file permissions
        |
        v
Mode = 0000
        |
        v
Confirm service user
        |
        v
rhanly owns file but cannot read it
        |
        v
ROOT CAUSE IDENTIFIED
```

## Lessons Learned

- A systemd restart loop is a symptom, not necessarily the root cause.
- Automatic restart cannot recover from a persistent filesystem permission problem.
- `journalctl` is essential for identifying the application exception behind a failed service.
- File ownership alone does not guarantee access.
- `ls -l` provides a fast view of Linux permission bits.
- `stat` provides detailed permission, UID, and GID information.
- `id` and `systemctl show` help verify the effective service identity.
- Direct backend testing helps distinguish application startup failures from reverse proxy or network failures.
- Linux permission problems can appear at the application layer even when the application code itself is correct.

## Preventive Actions

- Document expected ownership and permissions for required configuration files.
- Validate required file readability before deployment.
- Add a startup or deployment preflight check.
- Avoid granting broader permissions than necessary.
- Monitor repeated systemd restarts.
- Review logs before repeatedly restarting failed services.
- Consider deployment validation that checks required configuration files before the new service version is started.

## Commands Used

```bash
sudo systemctl cat cloud-reliability-lab
sudo systemctl show cloud-reliability-lab -p User -p Group
ps -eo user,group,pid,cmd | grep '[u]vicorn'

ls -l config/app.conf
stat config/app.conf
id rhanly

chmod 000 config/app.conf

sudo systemctl restart cloud-reliability-lab
sudo systemctl status cloud-reliability-lab --no-pager

curl http://127.0.0.1:8000/

journalctl -u cloud-reliability-lab -n 50 --no-pager

chmod 664 config/app.conf

sudo systemctl restart cloud-reliability-lab

curl http://127.0.0.1:8000/
curl http://127.0.0.1/health
curl http://192.168.1.216/health
```
