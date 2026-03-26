from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI(title="Frontend Service")


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "frontend"}


@app.get("/", response_class=HTMLResponse)
def index():
    return """
<!doctype html>
<html>
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>Multi Service DevOps</title>
  <style>
    body { font-family: sans-serif; margin: 2rem; background: #f7f9fc; color: #1f2937; }
    .card { background: white; border-radius: 12px; padding: 1rem; margin-bottom: 1rem; box-shadow: 0 4px 14px rgba(0,0,0,.06); }
    h1 { margin-top: 0; }
    code { background: #eef2f7; padding: 2px 6px; border-radius: 6px; }
  </style>
</head>
<body>
  <div class=\"card\">
    <h1>Multi-Service Platform</h1>
    <p>Frontend is running.</p>
    <p>Try gateway routes:</p>
    <ul>
      <li><code>/auth/healthz</code></li>
      <li><code>/core/healthz</code></li>
      <li><code>/users/healthz</code></li>
      <li><code>/tasks/healthz</code></li>
      <li><code>/notifications/healthz</code></li>
    </ul>
  </div>
</body>
</html>
"""
