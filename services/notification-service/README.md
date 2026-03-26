# Notification Service

## Purpose
Notification service accepts notification requests and tracks them in memory.

## Main Components
- Pydantic models:
  - `NotificationIn`: input payload (`user_id`, `channel`, `message`).
  - `NotificationOut`: output payload with generated `id`, `sent_at`, and `status`.
- In-memory queue:
  - `notifications: list[NotificationOut]`

## Request Flow
1. `POST /notifications` receives a notification request.
2. Service stamps it with ID and UTC timestamp.
3. Record is appended to in-memory list and returned.
4. `GET /notifications` retrieves all records or filters by `user_id`.

## Routes
- `GET /healthz`: health check plus queued count.
- `POST /notifications`: queue a notification.
- `GET /notifications`: list notifications (optional `user_id` filter).

## Notes
- This is a queue simulation, not a real sender.
- Useful as a placeholder before integrating email/SMS providers.

## Run Locally
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```
