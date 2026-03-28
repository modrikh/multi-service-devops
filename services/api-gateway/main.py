from fastapi import FastAPI, Request, HTTPException, Response
import httpx
import os

app = FastAPI(title="API Gateway")

# URLs of internal services, injected via K8s Environment variables
AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8001")
CORE_SERVICE_URL = os.getenv("CORE_SERVICE_URL", "http://core-service:8002")
USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://user-service:8003")
TASK_SERVICE_URL = os.getenv("TASK_SERVICE_URL", "http://task-service:8004")
NOTIFICATION_SERVICE_URL = os.getenv("NOTIFICATION_SERVICE_URL", "http://notification-service:8005")
FRONTEND_SERVICE_URL = os.getenv("FRONTEND_SERVICE_URL", "http://frontend:8006")

@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "api-gateway"}

@app.api_route("/", methods=["GET", "HEAD"])
async def route_root_to_frontend(request: Request):
    """Serve frontend homepage through gateway root path."""
    return await proxy_request(f"{FRONTEND_SERVICE_URL}/", request)

@app.api_route("/frontend", methods=["GET", "HEAD"])
async def route_frontend_base(request: Request):
    """Support /frontend without requiring a trailing sub-path."""
    return await proxy_request(f"{FRONTEND_SERVICE_URL}/", request)

@app.api_route("/auth/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def route_to_auth(path: str, request: Request):
    """Proxy requests starting with /auth to the Auth Service."""
    url = f"{AUTH_SERVICE_URL}/{path}"
    return await proxy_request(url, request)

@app.api_route("/core/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def route_to_core(path: str, request: Request):
    """Proxy requests starting with /core to the Core Service."""
    url = f"{CORE_SERVICE_URL}/{path}"
    return await proxy_request(url, request)

@app.api_route("/users/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def route_to_user(path: str, request: Request):
    """Proxy requests starting with /users to the User Service."""
    url = f"{USER_SERVICE_URL}/{path}"
    return await proxy_request(url, request)

@app.api_route("/tasks/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def route_to_task(path: str, request: Request):
    """Proxy requests starting with /tasks to the Task Service."""
    url = f"{TASK_SERVICE_URL}/{path}"
    return await proxy_request(url, request)

@app.api_route("/notifications/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def route_to_notification(path: str, request: Request):
    """Proxy requests starting with /notifications to the Notification Service."""
    url = f"{NOTIFICATION_SERVICE_URL}/{path}"
    return await proxy_request(url, request)

@app.api_route("/frontend/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def route_to_frontend(path: str, request: Request):
    """Proxy requests starting with /frontend to the Frontend Service."""
    url = f"{FRONTEND_SERVICE_URL}/{path}"
    return await proxy_request(url, request)

async def proxy_request(url: str, request: Request):
    # Retrieve body and headers
    body = await request.body()
    headers = dict(request.headers)
    # Remove host header so httpx correctly calculates it
    headers.pop("host", None)
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.request(
                method=request.method,
                url=url,
                headers=headers,
                content=body,
            )
            content_type = response.headers.get("content-type", "")
            if "application/json" in content_type:
                return Response(
                    content=response.content,
                    status_code=response.status_code,
                    media_type="application/json",
                )
            return Response(
                content=response.content,
                status_code=response.status_code,
                media_type=content_type or None,
            )
        except httpx.RequestError as exc:
            raise HTTPException(status_code=502, detail=f"Service unavailable: {exc}")
