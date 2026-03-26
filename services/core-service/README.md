# Core Service

## Purpose
Core service contains business data logic for `items` with persistent storage through SQLAlchemy.

## Main Components
- Database setup:
  - `DATABASE_URL` from environment.
  - Fallback local SQLite: `sqlite:///./test.db`.
- SQLAlchemy model:
  - `Item(id, name, description)`.
- Pydantic schemas:
  - `ItemCreate`: input schema.
  - `ItemResponse`: output schema including `id`.
- `get_db()`: dependency that opens and closes DB sessions per request.

## Request Flow
1. Service initializes database engine and creates tables.
2. `POST /items/` inserts a new item.
3. `GET /items/` retrieves paginated items.

## Routes
- `GET /healthz`: health check.
- `POST /items/`: create one item.
- `GET /items/`: list items with `skip` and `limit` query params.

## Notes
- SQLite is convenient for local development.
- Use PostgreSQL in containerized environments by setting `DATABASE_URL`.

## Run Locally
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```
