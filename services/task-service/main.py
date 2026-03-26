from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Task Service")


class TaskCreate(BaseModel):
    title: str
    description: str = ""
    user_id: int


class TaskUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    completed: bool | None = None


class TaskResponse(TaskCreate):
    id: int
    completed: bool = False


tasks: dict[int, TaskResponse] = {}
next_id = 1


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "task", "tasks": len(tasks)}


@app.post("/tasks", response_model=TaskResponse)
def create_task(payload: TaskCreate):
    global next_id
    task = TaskResponse(
        id=next_id,
        title=payload.title,
        description=payload.description,
        user_id=payload.user_id,
        completed=False,
    )
    tasks[next_id] = task
    next_id += 1
    return task


@app.get("/tasks", response_model=list[TaskResponse])
def list_tasks(user_id: int | None = None):
    if user_id is None:
        return list(tasks.values())
    return [task for task in tasks.values() if task.user_id == user_id]


@app.get("/tasks/{task_id}", response_model=TaskResponse)
def get_task(task_id: int):
    task = tasks.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@app.put("/tasks/{task_id}", response_model=TaskResponse)
def update_task(task_id: int, payload: TaskUpdate):
    task = tasks.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    data = task.model_dump()
    updates = payload.model_dump(exclude_unset=True)
    data.update(updates)
    updated = TaskResponse(**data)
    tasks[task_id] = updated
    return updated
