# API Gateway Service

## Purpose
The API Gateway is the single entry point for client traffic. It receives requests and forwards them to the correct internal service.

## Main Components
- `app = FastAPI(...)`: bootstraps the gateway API.
- Service URL environment variables:
  - `AUTH_SERVICE_URL`
  - `CORE_SERVICE_URL`
  - `USER_SERVICE_URL`
  - `TASK_SERVICE_URL`
  - `NOTIFICATION_SERVICE_URL`
  - `FRONTEND_SERVICE_URL`
- `proxy_request(...)`: shared function that forwards method, headers, and body to target services using `httpx`.

## Request Flow
1. A request hits a prefixed route like `/auth/...`.
2. Gateway maps it to the target service URL.
3. Gateway forwards request details with `httpx.AsyncClient`.
4. Gateway returns downstream response content and status code.

## Routes
- `GET /healthz`: gateway health check.
- `ANY /auth/{path}`: forwards to Auth service.
- `ANY /core/{path}`: forwards to Core service.
- `ANY /users/{path}`: forwards to User service.
- `ANY /tasks/{path}`: forwards to Task service.
- `ANY /notifications/{path}`: forwards to Notification service.
- `ANY /frontend/{path}`: forwards to Frontend service.

## Error Handling
- On downstream connectivity errors, returns `502 Bad Gateway` with detail from `httpx.RequestError`.

## Run Locally
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```
