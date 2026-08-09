# Incident: nginx Reverse Proxy Upstream Failure

## Date

2026-08-09

## Scenario

A controlled configuration failure was introduced into the nginx reverse proxy by changing the FastAPI upstream port from the correct port `8000` to the unused port `8001`.

The purpose of the exercise was to practice tracing an HTTP failure backward through the application stack and identifying whether the problem existed in nginx, the FastAPI application, or the connection between them.

## Architecture

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

During the failure test, nginx was intentionally configured as:

```text
Client
  |
  v
nginx :80
  |
  v
127.0.0.1:8001
  |
  X
No service listening
```

## Failure Injection

The nginx site configuration was modified from:

```nginx
proxy_pass http://127.0.0.1:8000;
```

to:

```nginx
proxy_pass http://127.0.0.1:8001;
```

Screenshot:

![Incorrect nginx upstream configuration](../screenshots/incidents/nginx-reverse-proxy-failure/nginx-wrong-upstream-config.png)

## Initial Validation

The nginx configuration was tested with:

```bash
sudo nginx -t
```

Result:

```text
syntax is ok
test is successful
```

nginx was then reloaded:

```bash
sudo systemctl reload nginx
```

The reload completed successfully.

This demonstrated that the configuration was syntactically valid even though it was operationally incorrect.

## Impact

Requests sent through nginx failed:

```bash
curl http://127.0.0.1/health
```

Result:

```text
502 Bad Gateway
```

However, a direct request to the FastAPI application succeeded:

```bash
curl http://127.0.0.1:8000/health
```

Result:

```json
{
  "status": "ok",
  "hostname": "hp-homelab"
}
```

This showed that the FastAPI service itself remained healthy.

## Investigation

### 1. Check nginx service status

```bash
sudo systemctl status nginx --no-pager
```

Result:

```text
active (running)
```

This confirmed that nginx itself had not crashed.

### 2. Check listening TCP ports

```bash
ss -ltnp | grep -E ':80|:8000|:8001'
```

Observed listeners:

```text
0.0.0.0:80
127.0.0.1:8000
```

No process was listening on:

```text
127.0.0.1:8001
```

This suggested that nginx was attempting to forward requests to a port where no backend service existed.

### 3. Review nginx error logs

```bash
sudo tail -n 30 /var/log/nginx/cloud-reliability-lab-error.log
```

The nginx error log reported:

```text
connect() failed (111: Connection refused) while connecting to upstream
```

The failed upstream was:

```text
http://127.0.0.1:8001/health
```

### 4. Inspect nginx upstream configuration

```bash
sudo grep -n "proxy_pass" /etc/nginx/sites-available/cloud-reliability-lab
```

Result:

```text
proxy_pass http://127.0.0.1:8001;
```

This confirmed the configuration mismatch.

## Evidence

![nginx reverse proxy troubleshooting](../screenshots/incidents/nginx-reverse-proxy-failure/nginx-failure-troubleshooting.png)

## Failing Layer

```text
Reverse Proxy Configuration
```

The Linux host was healthy.

nginx was healthy.

The FastAPI application was healthy.

The failure occurred in the configuration connecting nginx to the FastAPI backend.

## Root Cause

nginx was configured to proxy requests to:

```text
127.0.0.1:8001
```

while the FastAPI/Uvicorn application was actually listening on:

```text
127.0.0.1:8000
```

Because nothing was listening on port `8001`, nginx received a TCP connection refusal from the upstream and returned HTTP `502 Bad Gateway` to the client.

## Resolution

The known-good nginx configuration was restored:

```bash
sudo cp \
/etc/nginx/sites-available/cloud-reliability-lab.backup \
/etc/nginx/sites-available/cloud-reliability-lab
```

The restored configuration was validated:

```bash
sudo nginx -t
```

nginx was then reloaded:

```bash
sudo systemctl reload nginx
```

## Recovery Validation

Recovery was verified at each layer:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1/health
curl http://192.168.1.216/health
```

Expected result:

```text
All health checks return HTTP 200.
```

## Troubleshooting Path

```text
HTTP request fails
        |
        v
502 Bad Gateway
        |
        v
Is nginx running?
        |
       Yes
        |
        v
Does FastAPI work directly?
        |
       Yes
        |
        v
Which ports are listening?
        |
        v
80 and 8000
8001 absent
        |
        v
Check nginx error log
        |
        v
Connection refused to 127.0.0.1:8001
        |
        v
Inspect proxy_pass
        |
        v
nginx configured for wrong upstream port
        |
        v
ROOT CAUSE IDENTIFIED
```

## Lessons Learned

- `nginx -t` validates configuration syntax, not whether the configured backend actually exists or is reachable.
- An HTTP `502 Bad Gateway` can indicate that the reverse proxy is healthy while its upstream dependency is unavailable.
- Testing the backend directly helps isolate whether a failure is in the application or the reverse proxy layer.
- `ss -ltnp` is useful for confirming which services are actually listening on expected ports.
- nginx error logs provide direct evidence about failed upstream connections.
- Layer-by-layer troubleshooting is more effective than restarting services without understanding the failure.

## Preventive Improvements

- Always run `nginx -t` before reloads.
- Validate upstream ports during deployment.
- Include a post-deployment health check through nginx.
- Include a direct backend health check when diagnosing proxy failures.
- Maintain version-controlled nginx configuration.
- Consider automated rollback when post-deployment health checks fail.
