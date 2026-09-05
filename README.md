# Cineva

Nền tảng xem phim (monorepo): giao diện công khai + quản trị nội dung.

```
frontend/   Nuxt 4 · Vue 3 · Element Plus · Pinia · i18n
backend/    FastAPI · SQLAlchemy 2 · Alembic · PostgreSQL · Scalar
```

> **Lưu ý:** Toàn bộ dự án mang tính chất học tập / nghiên cứu. Tác giả **không chịu trách nhiệm** nếu bạn dùng cho mục đích thương mại hoặc bất kỳ mục đích nào khác ngoài học tập.

## Tính năng chính

**Công khai**
- Trang chủ, danh mục / tìm kiếm phim, trang chi tiết, xem tập
- Đăng ký / đăng nhập (Cloudflare Turnstile)
- Tủ phim, lịch sử đã xem, theo dõi / đánh giá / bình luận (khi đã đăng nhập)

**Quản trị**
- Kho phim, đồng bộ catalog (thủ công + lịch 00:00 Asia/Ho_Chi_Minh)
- Banner trang chủ, phim nổi bật, duyệt bình luận
- Người dùng / vai trò / quyền, nhật ký hệ thống
- Dashboard: thống kê, lưu lượng truy cập 7 ngày, trạng thái server

## Yêu cầu

| Thành phần | Phiên bản |
|------------|-----------|
| Node.js | 20+ (khuyến nghị) |
| Python | 3.11+ |
| [uv](https://docs.astral.sh/uv/) | mới nhất |
| Docker | cho Postgres / full stack |
| Cloudflare Turnstile | site key + secret (dev: key test trong `.env.example`) |

## Chạy local

### 1. Database

```bash
docker compose up -d db
```

Postgres: `localhost:5432` · DB `cineva` · user/pass `postgres` / `password123`

### 2. Backend

```bash
cd backend
uv sync --extra dev

# macOS / Linux:
cp .env.example .env
# Windows:
# copy .env.example .env

uv run alembic upgrade head
uv run python scripts/seed.py
uv run uvicorn app.main:app --reload --port 8000
```

- Docs (Scalar): http://localhost:8000/api/docs  
- OpenAPI: http://localhost:8000/api/openapi.json  
- Admin mặc định (seed): `admin` / `admin123456`

Dependencies nằm trong `pyproject.toml` + `uv.lock` (không dùng `requirements.txt`).  
Thêm / gỡ package: `uv add <pkg>` / `uv remove <pkg>`.

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
cp .env.example .env
# Chỉnh JWT_SECRET, mật khẩu, CORS_ORIGINS, NUXT_PUBLIC_WS_BASE nếu deploy ra ngoài localhost

docker compose up --build -d
```

| Service | URL (mặc định) |
|---------|----------------|
| Web | http://localhost:3000 |
| API | http://localhost:8000 |
| Docs | http://localhost:8000/api/docs |

Admin seed: giá trị `DEFAULT_ADMIN_*` trong `.env` (mặc định `admin` / `admin123456`).

`docker-compose.yml` đọc `.env` ở thư mục gốc (`env_file`, `${VAR:-default}`, volume `cineva_*`).  
Tên image lấy từ `API_DOCKER_IMAGE` / `WEB_DOCKER_IMAGE` trong `.env`.

**Build + push registry (máy dev):**

```bash
docker login
docker compose build
docker push "$API_DOCKER_IMAGE"
docker push "$WEB_DOCKER_IMAGE"
```

**Trên VPS (kéo image, không build):** copy `docker-compose.yml` + `.env`, rồi:

```bash
docker compose pull
docker compose up -d
```

```bash
docker compose logs -f
docker compose down          # giữ volume
docker compose down -v       # xóa DB + uploads
```

## Kiến trúc

```
Browser → Nuxt (:3000) ──proxy /api, /uploads──→ FastAPI (:8000) → Postgres
                      └── WS (NUXT_PUBLIC_WS_BASE) ──→ FastAPI WebSocket
```

Backend theo lớp: `api/routes` → `services` → `repositories` → `models` (+ Pydantic `schemas`).

**Auth**
- Trình duyệt: HttpOnly cookies (`auth_token` / `refresh_token`) + CSRF — không gửi Bearer từ Nuxt
- API / Scalar: `POST /api/auth/token` (OAuth2 password) → Bearer; refresh bằng `grant_type=refresh_token`

**Gọi API từ frontend:** dùng `useApiFetch` / `apiFetch` (relative `/api/...`), không dùng bare `$fetch` cho `/api/**`.

## Biến môi trường

| File | Mục đích |
|------|----------|
| `.env` (root) | Docker Compose + inject vào `api` / `web` / `db` — copy từ `.env.example` |
| `backend/.env` | Chạy API local (không Docker) |
| `frontend/.env` | Chạy Nuxt local (không Docker) |

## Cấu trúc thư mục (tóm tắt)

```
frontend/
  pages/          Route Nuxt (công khai + admin)
  components/     UI tái sử dụng (CSS Modules)
  stores/         Pinia (auth, …)
  i18n/locales/   Bản dịch (vi)
backend/
  app/
    api/          Routes, deps, CSRF, rate limit
    services/     Nghiệp vụ (films, auth, traffic, sync, …)
    repositories/ Truy vấn SQLAlchemy
    models/       ORM
    schemas/      Pydantic I/O
  alembic/        Migrations
  scripts/        Seed, tiện ích
```

## Ghi chú vận hành

- Schema SQLAlchemy dùng **snake_case** (`users`, `full_name`, …). Nếu volume Postgres lệch schema (đổi nhánh / DB cũ): `docker compose down -v` rồi chạy lại migrate + seed.
- Turnstile key test chấp nhận token `XXXX.DUMMY.TOKEN.XXXX` (login/register web).
- Đồng bộ phim: lịch hàng ngày lúc **00:00** (Asia/Ho_Chi_Minh); có thể chạy thủ công từ `/films/sync`.
- Theme UI cố định dark; ngôn ngữ mặc định tiếng Việt.

## Scripts hữu ích

```bash
# Backend
cd backend
uv run alembic upgrade head
uv run alembic revision --autogenerate -m "mo_ta"
uv run ruff check .

# Frontend
cd frontend
npm run typecheck
npm run build
```
