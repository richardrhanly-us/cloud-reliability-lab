# Runbook: Application Crash

## Scenario

The FastAPI application process stops unexpectedly.

## Impact

Users cannot reach the application health endpoint if the service fails and does not recover.

Expected endpoint:

```text
http://192.168.1.216/health
