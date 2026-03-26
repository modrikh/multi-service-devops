# Task Service

## Purpose
Task service manages user tasks (create, read, and update) using in-memory storage.

## Main Components
- Pydantic models:
  - `TaskCreate`: title, description, and owner `user_id`.
  - `TaskUpdate`: partial update model.
  - `TaskResponse`: output model including `id` and `completed` state.
- In-memory store:
  - `tasks: dict[int, TaskResponse]`
  - `next_id` auto-increment counter.

## Request Flow
1. `POST /tasks` creates a task with `completed=False`.
2. `GET /tasks` lists tasks (optionally filtered by `user_id`).
3. `GET /tasks/{task_id}` fetches one task.
4. `PUT /tasks/{task_id}` applies partial updates.

## Routes
- `GET /healthz`: health check plus task count.
- `POST /tasks`: create task.
- `GET /tasks`: list tasks or filter by `user_id`.
- `GET /tasks/{task_id}`: fetch one task.
- `PUT /tasks/{task_id}`: update existing task.

## Notes
- Current storage is in-memory, so restart clears tasks.
- `TaskUpdate` uses partial updates with only provided fields.

## Run Locally
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```
