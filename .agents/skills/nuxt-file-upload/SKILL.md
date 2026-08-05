---
name: nuxt-file-upload
description: >-
  File upload conventions for this monorepo: FastAPI validation + storage under backend/uploads,
  served at /uploads, Nuxt proxies /uploads to the API.
  Use when implementing avatar/document/image upload or multipart handling.
  Triggers on "upload", "file upload", "avatar", "multipart", "el-upload", "tải lên", "attachment".
---

# File Upload

## Storage

- Directory: `backend/uploads/` (env `UPLOAD_DIR`, default `uploads`)
- Avatars: `uploads/avatars/{uuid}{ext}`
- FastAPI mounts StaticFiles at `/uploads`
- Nuxt proxies `/uploads/**` → FastAPI (`NUXT_API_PROXY`)
- Docker: volume `api_uploads` on the `api` service

## Server pattern

`POST /api/users/avatar` (`backend/app/services/users.py`):

1. Auth required (`get_current_user`).
2. Validate MIME (`jpeg|png|gif|webp`), extension, max size (e.g. 5MB).
3. Generate safe filename (`uuid4` + allowed ext) — never trust client filename alone.
4. Write under `UPLOAD_DIR/avatars/`.
5. Save public path `/uploads/avatars/...` on the user row.
6. Return `{ success, data: { avatar } }`.

## Client

```typescript
const fd = new FormData()
fd.append('file', file)
const res = await $fetch('/api/users/avatar', { method: 'POST', body: fd })
// display: res.data.avatar  (same-origin /uploads via Nuxt proxy)
```

## Rules

- Validate on **server** only (MIME + size + ext).
- Tenant/user ownership via auth context — do not accept arbitrary user ids for avatar without permission.
- Do not commit uploaded binaries to git; keep `backend/uploads/` gitignored.
- Prefer relative `/uploads/...` URLs so proxy/CDN can sit in front.

## Checklist

- [ ] MIME / size / extension checks
- [ ] Safe stored filename
- [ ] Files under `UPLOAD_DIR`, served via `/uploads`
- [ ] Frontend uses `/api/...` upload + `/uploads/...` display (proxied)
