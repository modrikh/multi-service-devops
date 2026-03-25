from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
import jwt
import datetime

app = FastAPI(title="Auth Service")

SECRET_KEY = "my_super_secret_dev_key"
ALGORITHM = "HS256"

class LoginData(BaseModel):
    username: str
    password: str

class TokenCheck(BaseModel):
    token: str

@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "auth"}

@app.post("/login")
def login(user: LoginData):
    # Mock database check
    if user.username == "admin" and user.password == "admin123":
        # Create JWT token
        payload = {
            "sub": user.username,
            "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=1)
        }
        token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
        return {"access_token": token, "type": "bearer"}
    raise HTTPException(status_code=401, detail="Invalid credentials")

@app.post("/validate")
def validate_token(request: TokenCheck):
    try:
        decoded = jwt.decode(request.token, SECRET_KEY, algorithms=[ALGORITHM])
        return {"valid": True, "user": decoded["sub"]}
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
