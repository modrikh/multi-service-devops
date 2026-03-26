from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr

app = FastAPI(title="User Service")


class UserCreate(BaseModel):
    username: str
    email: EmailStr


class UserResponse(UserCreate):
    id: int


users: dict[int, UserResponse] = {}
next_id = 1


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "user", "users": len(users)}


@app.post("/users", response_model=UserResponse)
def create_user(payload: UserCreate):
    global next_id
    user = UserResponse(id=next_id, username=payload.username, email=payload.email)
    users[next_id] = user
    next_id += 1
    return user


@app.get("/users", response_model=list[UserResponse])
def list_users():
    return list(users.values())


@app.get("/users/{user_id}", response_model=UserResponse)
def get_user(user_id: int):
    user = users.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
