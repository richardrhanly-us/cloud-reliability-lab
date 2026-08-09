# Runbook: Filesystem Permission Failure

## Purpose

Use this runbook when the Cloud Reliability Lab application fails to start or repeatedly crashes because it cannot read a required file.

This runbook helps isolate whether the failure is caused by:

- incorrect file permissions
- incorrect file ownership
- the systemd service account lacking access
- a missing required configuration file

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

## Known Required File

The application reads:

```text
config/app.conf
```

Expected contents:

```text
environment=homelab
```

Expected ownership:

```text
rhanly:rhanly
```

Expected permissions:

```text
-rw-rw-r--
```

Equivalent numeric mode:

```text
664
```

## Common Symptoms

Possible symptoms include:

- application fails to start
- systemd enters an automatic restart loop
- port `8000` is no longer listening
- health checks fail
- `curl` cannot connect to the FastAPI backend
- `journalctl` reports `PermissionError`
- application logs reference `config/app.conf`

## 1. Check Service Status

```bash
sudo systemctl status cloud-reliability-lab --no-pager
```

A permission failure may appear as:

```text
Active: activating (auto-restart) (Result: exit-code)
```

or:

```text
status=1/FAILURE
```

If the service is repeatedly restarting, do not assume systemd itself is the root cause.

Continue to the application logs.

## 2. Test the Application Directly

```bash
curl http://127.0.0.1:8000/
```

A failed startup may produce:

```text
curl: (7) Failed to connect to 127.0.0.1 port 8000
```

This confirms that the backend is not currently accepting connections.

## 3. Review Service Logs

```bash
journalctl -u cloud-reliability-lab -n 50 --no-pager
```

Look near the bottom of the traceback for the actual exception.

A filesystem permission failure may appear as:

```text
PermissionError: [Errno 13] Permission denied: 'config/app.conf'
```

This indicates that the application attempted to open the file but the operating system denied access.

## 4. Confirm the Service Account

Check the systemd unit:

```bash
sudo systemctl cat cloud-reliability-lab
```

Look for:

```ini
User=rhanly
Group=rhanly
```

You can also confirm the effective service identity with:

```bash
sudo systemctl show cloud-reliability-lab -p User -p Group
```

Expected result:

```text
User=rhanly
Group=rhanly
```

## 5. Inspect File Permissions

```bash
ls -l config/app.conf
```

Expected healthy state:

```text
-rw-rw-r-- 1 rhanly rhanly ... config/app.conf
```

A broken permission state may appear as:

```text
---------- 1 rhanly rhanly ... config/app.conf
```

This means no user, group, or other account has permission to read or write the file.

## 6. Inspect Detailed File Metadata

```bash
stat config/app.conf
```

Expected healthy permissions:

```text
Access: (0664/-rw-rw-r--)
```

A failed permission state may show:

```text
Access: (0000/----------)
```

Also confirm ownership:

```text
Uid: (1000/rhanly)
Gid: (1000/rhanly)
```

## 7. Confirm the Service User Identity

```bash
id rhanly
```

Expected output should confirm that the service account exists and belongs to the expected user and group.

This helps verify that the account attempting to read the file is the same account referenced by systemd.

## Troubleshooting Decision Path

```text
Application unavailable
        |
        v
Check systemd service
        |
        v
Service exiting / restarting
        |
        v
Check journalctl
        |
        v
PermissionError on config/app.conf
        |
        v
Confirm service user
        |
        v
Inspect file ownership and mode
        |
        v
Permissions = 0000
        |
        v
Service user cannot read file
        |
        v
ROOT CAUSE IDENTIFIED
```

## Known Failure Scenario

A controlled permission failure was introduced with:

```bash
chmod 000 config/app.conf
```

The file changed from:

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

Observed behavior:

```text
Active: activating (auto-restart) (Result: exit-code)
```

and:

```text
status=1/FAILURE
```

Direct application access failed:

```bash
curl http://127.0.0.1:8000/
```

Result:

```text
Could not connect to server
```

The service logs reported:

```text
PermissionError: [Errno 13] Permission denied: 'config/app.conf'
```

File inspection confirmed:

```text
Access: (0000/----------)
Uid: (1000/rhanly)
Gid: (1000/rhanly)
```

The application itself was not failing because of a code bug or network problem.

The root cause was an operating-system filesystem permission issue.

## Recovery

Restore the known-good file permissions:

```bash
chmod 664 config/app.conf
```

Confirm:

```bash
ls -l config/app.conf
```

Expected result:

```text
-rw-rw-r-- 1 rhanly rhanly ... config/app.conf
```

Restart the service:

```bash
sudo systemctl restart cloud-reliability-lab
```

## Verify Recovery

Check the service:

```bash
sudo systemctl status cloud-reliability-lab --no-pager
```

Expected state:

```text
active (running)
```

Test the FastAPI application directly:

```bash
curl http://127.0.0.1:8000/
```

Expected response includes:

```json
"config":"environment=homelab"
```

Test the health endpoint through nginx:

```bash
curl http://127.0.0.1/health
```

Test the LAN-facing endpoint:

```bash
curl http://192.168.1.216/health
```

All checks should return successfully.

## Root Cause

The required configuration file existed and was owned by the correct user, but its permissions were set to:

```text
0000
```

The systemd service runs as:

```text
rhanly
```

Because the `rhanly` account had no read permission on the file, Python failed when attempting to open:

```text
config/app.conf
```

This caused Uvicorn to exit during application startup.

systemd repeatedly attempted to restart the service, but automatic recovery could not succeed because the underlying filesystem permission problem remained unchanged.

## Lessons Learned

- A restart loop is often a symptom rather than the root cause.
- `journalctl` is critical for finding the actual application exception behind a failed systemd service.
- File ownership alone is not enough; permission bits determine whether the service account can actually access the file.
- `ls -l` provides a quick permission overview.
- `stat` provides detailed ownership and numeric permission information.
- `id` and `systemctl show` help confirm which account the application actually runs under.
- Automated service restart cannot recover from a persistent configuration or permission error.
- Testing the backend directly helps distinguish application startup failures from nginx or network failures.

## Prevention

- Keep required configuration files under controlled ownership and permissions.
- Document expected file modes.
- Validate required files during deployment.
- Add a startup or deployment check that confirms required files are readable.
- Avoid granting broader permissions than necessary.
- Monitor systemd restart counts for repeated startup failure.
- Review application logs before repeatedly restarting a failed service.

## Useful Commands

```bash
sudo systemctl status cloud-reliability-lab --no-pager
sudo systemctl cat cloud-reliability-lab
sudo systemctl show cloud-reliability-lab -p User -p Group

journalctl -u cloud-reliability-lab -n 50 --no-pager

curl http://127.0.0.1:8000/
curl http://127.0.0.1/health

ls -l config/app.conf
stat config/app.conf
id rhanly

chmod 664 config/app.conf

sudo systemctl restart cloud-reliability-lab
```
