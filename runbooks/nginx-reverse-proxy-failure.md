# Runbook: nginx Reverse Proxy Failure

## Purpose

Use this runbook when requests through nginx fail but the FastAPI application may still be running.

This runbook is designed to help isolate whether the failure is in:

- nginx itself
- the configured upstream port
- the FastAPI application
- the TCP connection between nginx and FastAPI

## Expected Architecture

```text
Client
  |
  v
nginx :80
  |
  v
FastAPI / Uvicorn
127.0.0.1:8000
```

## Common Symptoms

Possible symptoms include:

- HTTP `502 Bad Gateway`
- Uptime Kuma health check failure
- nginx error log entries
- FastAPI works directly but fails through nginx
- nginx is running but cannot connect to its upstream

## 1. Test the Application Through nginx

```bash
curl http://127.0.0.1/health
```

Expected healthy result:

```text
HTTP 200
```

If the request returns `502 Bad Gateway`, continue troubleshooting.

## 2. Test FastAPI Directly

```bash
curl http://127.0.0.1:8000/health
```

If this succeeds while the nginx request fails, the FastAPI application is healthy and the problem is likely in the reverse proxy layer.

## 3. Check nginx Status

```bash
sudo systemctl status nginx --no-pager
```

Expected healthy state:

```text
active (running)
```

If nginx is not running, inspect its logs before restarting it.

## 4. Validate nginx Configuration Syntax

```bash
sudo nginx -t
```

Expected result:

```text
syntax is ok
test is successful
```

Important:

A successful `nginx -t` only confirms that the configuration syntax is valid.

It does **not** confirm that the configured upstream service exists or is reachable.

## 5. Check Listening Ports

```bash
ss -ltnp | grep -E ':80|:8000|:8001'
```

Expected healthy listeners:

```text
0.0.0.0:80
127.0.0.1:8000
```

If nginx is configured for port `8001` but no service is listening there, nginx will be unable to reach the FastAPI backend.

## 6. Check nginx Error Logs

```bash
sudo tail -n 30 /var/log/nginx/cloud-reliability-lab-error.log
```

A reverse proxy connection failure may appear as:

```text
connect() failed (111: Connection refused) while connecting to upstream
```

Check the upstream address shown in the error.

Example:

```text
http://127.0.0.1:8001/health
```

## 7. Inspect the Configured Upstream

```bash
sudo grep -n "proxy_pass" \
/etc/nginx/sites-available/cloud-reliability-lab
```

Expected configuration:

```nginx
proxy_pass http://127.0.0.1:8000;
```

If nginx points to a different port than the one FastAPI is actually listening on, the reverse proxy configuration is incorrect.

## Troubleshooting Decision Path

```text
Request through nginx fails
        |
        v
Test FastAPI directly
        |
        +--> FastAPI also fails
        |       |
        |       v
        |   Investigate application/service layer
        |
        +--> FastAPI succeeds
                |
                v
        Check nginx service
                |
                v
        Check listening ports
                |
                v
        Check nginx error logs
                |
                v
        Inspect proxy_pass
                |
                v
        Identify upstream mismatch
```

## Known Failure Scenario

A validated failure occurred when nginx was configured as:

```nginx
proxy_pass http://127.0.0.1:8001;
```

while FastAPI remained on:

```text
127.0.0.1:8000
```

Observed behavior:

```text
curl http://127.0.0.1/health
```

returned:

```text
502 Bad Gateway
```

while:

```text
curl http://127.0.0.1:8000/health
```

returned a healthy response.

`ss -ltnp` showed:

```text
port 80    listening
port 8000  listening
port 8001  not listening
```

nginx logs reported:

```text
connect() failed (111: Connection refused) while connecting to upstream
```

## Recovery

If a known-good backup exists:

```bash
sudo cp \
/etc/nginx/sites-available/cloud-reliability-lab.backup \
/etc/nginx/sites-available/cloud-reliability-lab
```

Validate the restored configuration:

```bash
sudo nginx -t
```

Reload nginx:

```bash
sudo systemctl reload nginx
```

## Verify Recovery

Test FastAPI directly:

```bash
curl http://127.0.0.1:8000/health
```

Test through nginx locally:

```bash
curl http://127.0.0.1/health
```

Test from the LAN-facing address:

```bash
curl http://192.168.1.216/health
```

Expected result:

```text
All health checks return HTTP 200.
```

## Prevention

- Always run `sudo nginx -t` before reloading nginx.
- Keep nginx configuration in Git.
- Keep a known-good local backup before controlled testing.
- Validate backend ports during deployment.
- Monitor `/health` through nginx.
- Use direct backend health checks when isolating proxy failures.
- Add post-deployment validation so a bad upstream configuration is detected immediately.
- Consider automated rollback if post-deployment health checks fail.

## Useful Commands

```bash
sudo systemctl status nginx --no-pager
sudo nginx -t
ss -ltnp | grep -E ':80|:8000|:8001'
curl http://127.0.0.1/health
curl http://127.0.0.1:8000/health
sudo tail -n 30 /var/log/nginx/cloud-reliability-lab-error.log
sudo grep -n "proxy_pass" /etc/nginx/sites-available/cloud-reliability-lab
```
