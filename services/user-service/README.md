# User Service

## Purpose
User service manages basic user records in memory.

## Main Components
- Pydantic models:
  - `UserCreate`: input payload with `username` and `email`.
  - `UserResponse`: returned model with generated `id`.
- In-memory store:
  - `users: dict[int, UserResponse]`
  - `next_id` auto-increment counter.

## Request Flow
1. `POST /users` validates payload and stores new user in memory.
2. `GET /users` returns all users.
3. `GET /users/{user_id}` returns one user or 404.

## Routes
- `GET /healthz`: health check plus total user count.
- `POST /users`: create user.
- `GET /users`: list users.
- `GET /users/{user_id}`: fetch user by id.

## Notes
- Data is not persisted and resets when service restarts.
- Suitable as a scaffold while integrating a real database.

## Run Locally
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```
