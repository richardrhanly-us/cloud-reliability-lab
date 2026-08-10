# Runbook: Database Dependency Failure

## Purpose

Use this runbook when the FastAPI application is running but its PostgreSQL dependency is unavailable.

This runbook helps isolate whether the failure is caused by:

- PostgreSQL being stopped
- port `5432` not listening
- database connection refusal
- application readiness failure while the process itself remains healthy

## Expected Architecture

```text
Client
  |
  v
FastAPI
  |
  +--> /health
  |      |
  |      v
  |   process alive
  |
  +--> /ready
         |
         v
     PostgreSQL
     127.0.0.1:5432
```

## Expected Healthy State

The FastAPI process should be running:

```bash
sudo systemctl status cloud-reliability-lab --no-pager
```

The application health endpoint should return successfully:

```bash
curl http://127.0.0.1:8000/health
```

Expected:

```text
status: ok
```

The readiness endpoint should verify the database connection:

```bash
curl http://127.0.0.1:8000/ready
```

Expected:

```json
{
  "status": "ready",
  "database": "connected"
}
```

PostgreSQL should be running in Docker:

```bash
docker ps
```

Expected container:

```text
cloudlab-postgres
```

## Common Symptoms

Possible symptoms include:

- `/health` returns HTTP `200`
- `/ready` returns HTTP `503`
- FastAPI remains active
- Uvicorn continues listening on port `8000`
- PostgreSQL container is not running
- port `5432` is not listening
- readiness response reports `Connection refused`

## 1. Check Application Health

```bash
curl -i http://127.0.0.1:8000/health
```

If this succeeds, the FastAPI process is alive.

This means the failure is likely in a downstream dependency rather than the application process itself.

## 2. Check Application Readiness

```bash
curl -i http://127.0.0.1:8000/ready
```

A database dependency failure may return:

```text
HTTP/1.1 503 Service Unavailable
```

with an error similar to:

```text
connection to server at "127.0.0.1", port 5432 failed: Connection refused
```

This indicates that the application is alive but cannot reach PostgreSQL.

## 3. Check PostgreSQL Container Status

```bash
docker ps
```

If `cloudlab-postgres` is missing, check all containers:

```bash
docker ps -a --filter name=cloudlab-postgres
```

A stopped database container may appear as:

```text
Exited
```

## 4. Check Port 5432

```bash
ss -ltnp | grep 5432
```

Healthy state should show a listener on port `5432`.

If no output is returned, PostgreSQL is not listening on the expected TCP port.

## 5. Review PostgreSQL Logs

```bash
docker logs cloudlab-postgres --tail 20
```

Look for messages indicating:

- shutdown
- startup
- connection readiness
- fatal errors

A healthy PostgreSQL startup ends with:

```text
database system is ready to accept connections
```

## Troubleshooting Decision Path

```text
Application request fails
        |
        v
Check /health
        |
        +--> /health fails
        |       |
        |       v
        |   investigate application/service layer
        |
        +--> /health succeeds
                |
                v
            Check /ready
                |
                v
          /ready returns 503
                |
                v
      connection refused on 5432
                |
                v
         check docker ps
                |
                v
   cloudlab-postgres not running
                |
                v
          check port 5432
                |
                v
         no listener present
                |
                v
       ROOT CAUSE IDENTIFIED
```

## Known Failure Scenario

A controlled dependency failure was introduced with:

```bash
docker stop cloudlab-postgres
```

The FastAPI process remained healthy.

The health endpoint continued to return:

```text
HTTP 200
```

The readiness endpoint returned:

```text
HTTP 503 Service Unavailable
```

with:

```text
connection to server at "127.0.0.1", port 5432 failed: Connection refused
```

The PostgreSQL container no longer appeared in:

```bash
docker ps
```

and port `5432` was no longer listening.

## Root Cause

The PostgreSQL container was stopped.

The FastAPI process remained alive and continued serving requests, but the `/ready` endpoint performs a live database connectivity check.

Because PostgreSQL was not running, the TCP connection to:

```text
127.0.0.1:5432
```

was refused.

This caused the application to report itself as:

```text
not_ready
```

while remaining healthy at the process level.

## Recovery

Restart PostgreSQL:

```bash
docker start cloudlab-postgres
```

Confirm the container is running:

```bash
docker ps
```

Confirm PostgreSQL is listening:

```bash
ss -ltnp | grep 5432
```

## Verify Recovery

Check application health:

```bash
curl http://127.0.0.1:8000/health
```

Check readiness:

```bash
curl -i http://127.0.0.1:8000/ready
```

Expected readiness result:

```text
HTTP/1.1 200 OK
```

with:

```json
{
  "status": "ready",
  "database": "connected"
}
```

## Lessons Learned

- A healthy process does not guarantee that all application dependencies are healthy.
- `/health` and `/ready` serve different operational purposes.
- Readiness checks are useful for detecting dependency failures without treating the application process itself as dead.
- `Connection refused` usually indicates that the target host was reachable but nothing was listening on the requested port.
- `docker ps`, `ss`, and readiness endpoints provide complementary evidence.
- Dependency failures should be isolated before restarting healthy application processes.

## Prevention

- Monitor both `/health` and `/ready`.
- Alert on repeated readiness failures.
- Add restart policies for required database containers.
- Add deployment validation that confirms database connectivity.
- Monitor PostgreSQL container state and port `5432`.
- Consider a database retry policy for transient failures.
- Keep database dependency checks separate from basic process health checks.

## Useful Commands

```bash
sudo systemctl status cloud-reliability-lab --no-pager

curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1:8000/ready

docker ps
docker ps -a --filter name=cloudlab-postgres

ss -ltnp | grep 5432

docker logs cloudlab-postgres --tail 20

docker stop cloudlab-postgres
docker start cloudlab-postgres
```
