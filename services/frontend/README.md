# Frontend Service

## Purpose
Frontend service serves a simple HTML page that confirms platform status and points to gateway routes.

## Main Components
- `GET /healthz`: service health endpoint.
- `GET /`: returns inline HTML using `HTMLResponse`.
- HTML content includes quick route hints for downstream services.

## Request Flow
1. Browser requests `/`.
2. FastAPI returns a static HTML document.
3. User sees platform overview and test route list.

## Routes
- `GET /healthz`: health check.
- `GET /`: static landing page.

## Notes
- This is a minimal placeholder UI.
- Can be replaced by React/Vue/Angular static build or SSR app later.

## Run Locally
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```
