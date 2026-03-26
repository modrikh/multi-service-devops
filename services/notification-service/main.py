from datetime import datetime

from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Notification Service")


class NotificationIn(BaseModel):
    user_id: int
    channel: str = "email"
    message: str


class NotificationOut(NotificationIn):
    id: int
    sent_at: str
    status: str = "queued"


notifications: list[NotificationOut] = []


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "notification", "queued": len(notifications)}


@app.post("/notifications", response_model=NotificationOut)
def send_notification(payload: NotificationIn):
    record = NotificationOut(
        id=len(notifications) + 1,
        user_id=payload.user_id,
        channel=payload.channel,
        message=payload.message,
        sent_at=datetime.utcnow().isoformat(),
        status="queued",
    )
    notifications.append(record)
    return record


@app.get("/notifications", response_model=list[NotificationOut])
def list_notifications(user_id: int | None = None):
    if user_id is None:
        return notifications
    return [n for n in notifications if n.user_id == user_id]
