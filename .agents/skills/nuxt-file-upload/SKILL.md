---
name: nuxt-file-upload
description: >-
  File upload conventions for this Nuxt 3 SaaS project.
  Covers server-side validation (MIME type, size, extension), safe filename
  generation, tenant-scoped storage paths, serving files securely, and the
  Element Plus el-upload client pattern.
  Use when implementing avatar upload, document upload, image upload, or any
  file handling feature.
  Triggers on "upload", "file upload", "avatar", "multipart", "readMultipartFormData",
  "el-upload", "tải lên", "attachment".
---

# File Upload Pattern

> No upload feature exists yet — this skill defines the convention to follow
> when implementing one, consistent with the project's security model.
>
> **When you implement the first upload feature:** delete this note block and
> update the skill to reflect the actual implementation (real file paths,
> permission keys, and any deviations from the templates below).

## Security rules (CRITICAL)

1. **Whitelist MIME types AND extensions** — never trust `Content-Type` alone.
2. **Enforce size limits** server-side (client-side limit is UX only).
3. **Generate safe filenames** — never use the client's original filename for storage.
4. **Store under tenant-scoped paths** — `uploads/{tenant_id}/...`.
5. **Never serve the upload directory statically** — serve through an API
   endpoint that checks auth + tenant.
6. **Never execute or `import` uploaded content.**

## Server endpoint template

`server/api/upload/index.post.ts`:

```typescript
import { randomUUID } from 'node:crypto'
import { mkdir, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { requirePermission } from '../../utils/requirePermission'

// Whitelist per use case — keep it minimal
const ALLOWED_TYPES: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp'
}
const MAX_SIZE = 5 * 1024 * 1024 // 5MB

// Outside of public/ — never directly reachable by URL
const UPLOAD_ROOT = join(process.cwd(), 'uploads')

export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'update:users') // permission fitting the use case
    const tenant_id = event.context.tenant_id
    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' })
    }

    const parts = await readMultipartFormData(event)
    const file = parts?.find(p => p.name === 'file')
    if (!file?.data?.length) {
      throw createError({ statusCode: 400, statusMessage: 'No file uploaded' })
    }

    // 1. Size check
    if (file.data.length > MAX_SIZE) {
      throw createError({ statusCode: 413, statusMessage: 'File too large (max 5MB)' })
    }

    // 2. MIME whitelist (from multipart header)
    const ext = ALLOWED_TYPES[file.type || '']
    if (!ext) {
      throw createError({ statusCode: 415, statusMessage: 'File type not allowed' })
    }

    // 3. Magic bytes check (don't trust the declared MIME type)
    if (!hasValidMagicBytes(file.data, file.type!)) {
      throw createError({ statusCode: 415, statusMessage: 'File content does not match type' })
    }

    // 4. Safe filename: UUID + whitelisted extension — never client's name
    const filename = `${randomUUID()}${ext}`

    // 5. Tenant-scoped directory
    const dir = join(UPLOAD_ROOT, tenant_id)
    await mkdir(dir, { recursive: true })
    await writeFile(join(dir, filename), file.data)

    // 6. Return an API path (not a filesystem path)
    return { success: true, data: { url: `/api/files/${filename}` } }
  } catch (error: any) {
    console.error('API Error:', error)
    if (error.statusCode) throw error
    throw createError({ statusCode: 500, statusMessage: 'Lỗi hệ thống' })
  }
})

function hasValidMagicBytes(buf: Buffer, mime: string): boolean {
  if (mime === 'image/jpeg') return buf[0] === 0xff && buf[1] === 0xd8
  if (mime === 'image/png') return buf[0] === 0x89 && buf[1] === 0x50
  if (mime === 'image/webp') return buf.subarray(8, 12).toString() === 'WEBP'
  return false
}
```

## Serving files (auth-gated)

`server/api/files/[name].get.ts`:

```typescript
import { readFile } from 'node:fs/promises'
import { join, basename } from 'node:path'

const UPLOAD_ROOT = join(process.cwd(), 'uploads')

export default defineEventHandler(async (event) => {
  try {
    const tenant_id = event.context.tenant_id
    if (!tenant_id) {
      throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
    }

    // basename() strips any path traversal (../../etc/passwd)
    const name = basename(getRouterParam(event, 'name') || '')
    if (!name) throw createError({ statusCode: 400, statusMessage: 'Missing filename' })

    // Tenant scoping: users can only read their own tenant's files
    const filePath = join(UPLOAD_ROOT, tenant_id, name)

    const data = await readFile(filePath).catch(() => null)
    if (!data) throw createError({ statusCode: 404, statusMessage: 'Not found' })

    const ext = name.split('.').pop()
    const contentType =
      ext === 'jpg' ? 'image/jpeg' :
      ext === 'png' ? 'image/png' :
      ext === 'webp' ? 'image/webp' : 'application/octet-stream'

    setHeader(event, 'Content-Type', contentType)
    // Prevent uploaded files from executing scripts if opened directly
    setHeader(event, 'Content-Disposition', 'inline')
    setHeader(event, 'X-Content-Type-Options', 'nosniff')
    return data
  } catch (error: any) {
    if (error.statusCode) throw error
    throw createError({ statusCode: 500, statusMessage: 'Lỗi hệ thống' })
  }
})
```

## Client pattern (el-upload)

```vue
<el-upload
  :show-file-list="false"
  :auto-upload="false"
  accept="image/jpeg,image/png,image/webp"
  :on-change="onFileChange"
>
  <el-button :icon="Upload">{{ t('common.upload') }}</el-button>
</el-upload>
```

```typescript
const uploading = ref(false)

const onFileChange = async (uploadFile: UploadFile) => {
  const raw = uploadFile.raw
  if (!raw) return

  // Client-side pre-checks (UX only — server re-validates)
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(raw.type)) {
    ElMessage.error(t('upload.invalidType'))
    return
  }
  if (raw.size > 5 * 1024 * 1024) {
    ElMessage.error(t('upload.tooLarge'))
    return
  }

  uploading.value = true
  try {
    const formData = new FormData()
    formData.append('file', raw)

    const res = await $fetch<any>('/api/upload', {
      method: 'POST',
      body: formData
      // No Content-Type header — browser sets multipart boundary automatically
    })
    // use res.data.url ...
    ElMessage.success(t('upload.success'))
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || t('upload.failed'))
  } finally {
    uploading.value = false
  }
}
```

i18n keys to add (both `vi.json` and `en.json`):

```json
"upload": {
  "invalidType": "Định dạng file không hợp lệ",
  "tooLarge": "File quá lớn (tối đa 5MB)",
  "success": "Tải lên thành công",
  "failed": "Tải lên thất bại"
}
```

## Storing file references in DB

Store the API URL path (e.g. `/api/files/{uuid}.jpg`), not the filesystem path:

```prisma
model User {
  avatar String?  // "/api/files/3f2a...c9.jpg"
}
```

## Deployment note

The `uploads/` directory must:
- Be excluded from git (`.gitignore`)
- Persist across deployments (volume mount / object storage)
- For production scale, consider swapping local disk for S3-compatible storage —
  keep the same endpoint contract so the client doesn't change.

## Checklist

- [ ] MIME type whitelisted (both header check AND magic bytes)
- [ ] Extension derived from whitelist, never from client filename
- [ ] Size limit enforced server-side
- [ ] Filename is `randomUUID()` + whitelisted extension
- [ ] Files stored under `uploads/{tenant_id}/` (outside `public/`)
- [ ] Serving endpoint checks auth + scopes by `event.context.tenant_id`
- [ ] `basename()` used on filename params (path traversal prevention)
- [ ] `X-Content-Type-Options: nosniff` on served files
- [ ] `requirePermission()` called on the upload endpoint
- [ ] `writeSystemLog()` if the upload mutates a record (e.g. avatar change)
- [ ] Client: no manual `Content-Type` header on FormData requests
- [ ] i18n keys added for upload messages
- [ ] `uploads/` in `.gitignore`
