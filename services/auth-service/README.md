# Auth Service

## Purpose
Auth service handles user authentication and token validation using JWT.

## Main Components
- `SECRET_KEY`: loaded from environment variable and used to sign/verify JWTs.
- `ALGORITHM = "HS256"`: JWT signing algorithm.
- Pydantic models:
  - `LoginData`: request payload for login.
  - `TokenCheck`: request payload for token validation.

## Request Flow
1. `POST /login` receives username/password.
2. Service checks credentials (currently mocked: `admin/admin123`).
3. Service issues a JWT with `sub` and `exp` claims.
4. `POST /validate` verifies token validity and expiration.

## Routes
- `GET /healthz`: health check.
- `POST /login`: returns `{access_token, type}` when credentials are valid.
- `POST /validate`: returns `{valid: true, user: ...}` if token is valid.

## Notes
- Credential check is mock logic and should be replaced by a real user store.
- `SECRET_KEY` must be set in environment for secure token handling.

## Run Locally
```bash
export SECRET_KEY="change-me"
uvicorn main:app --host 0.0.0.0 --port 8000
```
