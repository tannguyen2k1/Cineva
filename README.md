# Admin Pro — Nuxt frontend + FastAPI backend

Monorepo tách FE/BE (nhánh **non_tenant**: single-org, không multi-tenant):

```
frontend/   Nuxt 4 UI (Element Plus, i18n, Pinia)
backend/    FastAPI + SQLAlchemy 2 + Alembic + Scalar docs
```

## Quick start (local)

### 1. Database

```bash
docker compose up -d db
```

### 2. Backend

```bash
cd backend
python3 -m venv .venv

# Activate venv
# macOS / Linux:
source .venv/bin/activate
# Windows (PowerShell):
# .venv\Scripts\Activate.ps1
# Windows (cmd):
# .venv\Scripts\activate.bat

pip install -e ".[dev]"

# Copy env
# macOS / Linux:
cp .env.example .env
# Windows:
# copy .env.example .env

# Edit .env if needed (JWT_SECRET / DB), then:
alembic upgrade head
python scripts/seed.py
uvicorn app.main:app --reload --port 8000
```

Dependencies live in `backend/pyproject.toml` (no `requirements.txt`).

- API docs (Scalar): http://localhost:8000/api/docs  
- OpenAPI JSON: http://localhost:8000/api/openapi.json  

Default admin (seed): `admin` / `admin123456`

### 3. Frontend

```bash
cd frontend

# macOS / Linux:
cp .env.example .env
# Windows:
# copy .env.example .env

npm install
npm run dev
```

App: http://localhost:3000  

Nuxt proxy `/api` và `/uploads` → FastAPI (`NUXT_API_PROXY`).  
WebSocket nối thẳng FastAPI (`NUXT_PUBLIC_WS_BASE`, mặc định `ws://127.0.0.1:8000`).

## Docker (full stack)

```bash
docker compose up --build
```

- Web: http://localhost:3000  
- API: http://localhost:8000  
- Docs: http://localhost:8000/api/docs  

## Architecture

```
Browser → Nuxt (:3000) ──proxy /api──→ FastAPI (:8000) → Postgres
                      └──proxy /ws──→ FastAPI WebSocket
```

Backend layers: `api/routes` → `services` → `repositories` → SQLAlchemy `models` (+ Pydantic `schemas`).  
Auth: httpOnly cookies `auth_token` / `refresh_token` + `auth_logged_in` (giống contract cũ).

## Env

| File | Purpose |
|------|---------|
| `backend/.env` | `DATABASE_URL`, `JWT_SECRET`, `TURNSTILE_SECRET_KEY`, admin defaults |
| `frontend/.env` | `NUXT_PUBLIC_TURNSTILE_SITE_KEY`, `NUXT_API_PROXY`, `NUXT_PUBLIC_WS_BASE` |

**Note:** Schema SQLAlchemy dùng snake_case (`users`, `full_name`, …). Nếu volume Postgres cũ từ Prisma (PascalCase), reset volume: `docker compose down -v`.
