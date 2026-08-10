# Incident: Database Dependency Failure

## Date

2026-08-09

## Scenario

A controlled database dependency failure was introduced into the Cloud Reliability Lab.

The FastAPI application depends on PostgreSQL running locally in Docker.

The purpose of the exercise was to practice distinguishing between:

- process health
- application readiness
- downstream dependency health

## Architecture

```text
Client
  |
  v
FastAPI / Uvicorn
127.0.0.1:8000
  |
  +--> /health
  |
  +--> /ready
         |
         v
     PostgreSQL
     127.0.0.1:5432
     cloudlab-postgres
```

## Baseline State

PostgreSQL was running in Docker:

```text
container: cloudlab-postgres
image: postgres:16
port: 5432
database: cloudlab
user: cloudlab
```

Database connectivity was verified with:

```bash
docker exec -it cloudlab-postgres \
psql -U cloudlab -d cloudlab \
-c "SELECT current_database(), current_user;"
```

The query returned:

```text
cloudlab | cloudlab
```

The FastAPI application was also healthy.

The health endpoint returned:

```text
status: ok
```

The readiness endpoint returned:

```json
{
  "status": "ready",
  "database": "connected"
}
```

## Failure Injection

The PostgreSQL container was intentionally stopped:

```bash
docker stop cloudlab-postgres
```

## Impact

The FastAPI application remained running.

The health endpoint continued to return successfully:

```bash
curl http://127.0.0.1:8000/health
```

Result:

```text
HTTP 200
```

However, the readiness endpoint failed:

```bash
curl -i http://127.0.0.1:8000/ready
```

Result:

```text
HTTP/1.1 503 Service Unavailable
```

The response reported:

```text
database unavailable
```

with:

```text
connection to server at "127.0.0.1", port 5432 failed: Connection refused
```

## Detection

The failure was detected through:

- `/ready` returning HTTP `503`
- PostgreSQL missing from `docker ps`
- connection refusal on port `5432`
- PostgreSQL container state inspection

## Investigation

### 1. Check Application Health

```bash
curl http://127.0.0.1:8000/health
```

The request succeeded.

This confirmed that the FastAPI process remained alive.

### 2. Check Application Readiness

```bash
curl -i http://127.0.0.1:8000/ready
```

The response returned:

```text
HTTP/1.1 503 Service Unavailable
```

with:

```text
Connection refused
```

on:

```text
127.0.0.1:5432
```

This narrowed the failure to the database dependency layer.

### 3. Check Running Containers

```bash
docker ps
```

The `cloudlab-postgres` container was absent.

### 4. Check Container State

```bash
docker ps -a --filter name=cloudlab-postgres
```

The PostgreSQL container showed a stopped/exited state.

### 5. Check TCP Listener

```bash
ss -ltnp | grep 5432
```

No listener was present on port `5432`.

This confirmed that the application had no database process available at the expected endpoint.

### 6. Review PostgreSQL Logs

```bash
docker logs cloudlab-postgres --tail 20
```

The logs showed PostgreSQL shutting down.

## Failing Layer

```text
Database Dependency
```

The following layers remained healthy:

- systemd
- Uvicorn
- FastAPI process
- application health endpoint

The failing layer was PostgreSQL availability.

## Root Cause

The PostgreSQL Docker container:

```text
cloudlab-postgres
```

had been stopped.

FastAPI continued running normally, but its `/ready` endpoint performs a live database connection test.

Because no process was listening on:

```text
127.0.0.1:5432
```

the TCP connection was refused.

The application correctly reported itself as unavailable for dependent work while remaining alive at the process level.

## Resolution

PostgreSQL was restarted:

```bash
docker start cloudlab-postgres
```

The container returned to the running state.

## Recovery Validation

Container status was verified:

```bash
docker ps
```

Application health was checked:

```bash
curl http://127.0.0.1:8000/health
```

Readiness was checked:

```bash
curl -i http://127.0.0.1:8000/ready
```

Expected recovery result:

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

## Troubleshooting Path

```text
Application still responding
        |
        v
/health returns 200
        |
        v
/ready returns 503
        |
        v
Database connection refused
        |
        v
Check docker ps
        |
        v
PostgreSQL not running
        |
        v
Check port 5432
        |
        v
No listener
        |
        v
ROOT CAUSE IDENTIFIED
```

## Evidence

Recommended screenshots:

```text
screenshots/incidents/database-dependency-failure/postgres-container-baseline.png
screenshots/incidents/database-dependency-failure/postgres-connection-baseline.png
screenshots/incidents/database-dependency-failure/health-and-readiness-baseline.png
screenshots/incidents/database-dependency-failure/database-down-readiness-failure.png
screenshots/incidents/database-dependency-failure/database-root-cause-confirmed.png
screenshots/incidents/database-dependency-failure/database-recovery-validated.png
```

## Lessons Learned

- Process health and dependency health are not the same thing.
- A service can be alive but not ready to handle dependency-dependent work.
- `/health` is useful for confirming that the application process is alive.
- `/ready` is useful for confirming that critical dependencies are available.
- HTTP `503` is appropriate when the application is temporarily unable to serve dependent operations.
- `Connection refused` indicates that the network path exists but no process is listening on the requested port.
- `docker ps`, `ss`, and application-level readiness checks provide a fast path to root cause.
- Restarting the FastAPI process would not have resolved the actual failure.

## Preventive Actions

- Monitor `/ready` independently from `/health`.
- Add alerting for database readiness failure.
- Configure a restart policy for PostgreSQL.
- Add dependency checks to deployment validation.
- Monitor container state and TCP listeners.
- Consider retry logic for short database outages.
- Avoid treating all health failures as application process failures.

## Commands Used

```bash
docker ps

docker exec -it cloudlab-postgres \
psql -U cloudlab -d cloudlab \
-c "SELECT current_database(), current_user;"

curl http://127.0.0.1:8000/health
curl -i http://127.0.0.1:8000/ready

docker stop cloudlab-postgres

docker ps
docker ps -a --filter name=cloudlab-postgres

ss -ltnp | grep 5432

docker logs cloudlab-postgres --tail 20

docker start cloudlab-postgres

curl http://127.0.0.1:8000/health
curl -i http://127.0.0.1:8000/ready
```
