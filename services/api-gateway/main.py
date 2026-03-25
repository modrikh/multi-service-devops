from fastapi import FastAPI, Request, HTTPException
import httpx
import os

app = FastAPI(title="API Gateway")

# URLs of internal services, injected via K8s Environment variables
AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8001")
CORE_SERVICE_URL = os.getenv("CORE_SERVICE_URL", "http://core-service:8002")

@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "api-gateway"}

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
            return response.json()
        except httpx.RequestError as exc:
            raise HTTPException(status_code=502, detail=f"Service unavailable: {exc}")
