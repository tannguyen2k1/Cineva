---
name: nuxt-i18n
description: >-
  Internationalization workflow for this Nuxt 3 project using @nuxtjs/i18n.
  Covers file locations, key naming conventions, adding new translations,
  keeping vi/en in sync, using t() correctly in components/forms/dialogs,
  and Element Plus locale integration.
  Use when adding new pages, creating UI features, fixing missing translations,
  or reviewing i18n consistency.
  Triggers on "i18n", "translation", "dịch", "ngôn ngữ", "locale", "t()",
  "vi.json", "en.json", "language", "multilingual".
---

# i18n Workflow

## Stack

- **Module**: `@nuxtjs/i18n` (configured in `nuxt.config.ts`)
- **Default locale**: `vi` (Vietnamese)
- **Strategy**: `no_prefix` (no `/vi/` or `/en/` path prefix)
- **Detection**: Cookie-based (`i18n_redirected`), fallback `vi`

## File locations

```
i18n/
└── locales/
    ├── vi.json    ← Vietnamese (default, authoritative)
    └── en.json    ← English
```

Both files must stay **in sync** — every key in `vi.json` must exist in `en.json` and vice versa.

## Key naming conventions

Keys are grouped by feature/resource. Use flat dot notation:

```
{group}.{key}
```

### Standard groups

| Group | Purpose | Example |
|-------|---------|---------|
| `app` | App-wide branding | `app.name`, `app.tagline` |
| `nav` | Sidebar/navigation labels | `nav.users`, `nav.products` |
| `pages` | Page titles (header/breadcrumb) | `pages.users`, `pages.products` |
| `header` | App header actions | `header.profile`, `header.logout` |
| `common` | Shared actions/labels (reuse!) | `common.cancel`, `common.save`, `common.delete` |
| `login` | Login page | `login.title`, `login.submit` |
| `lang` | Language names | `lang.vi`, `lang.en` |
| `{resource}` | Resource-specific CRUD | `users.add`, `roles.deleteConfirm` |

### Per-resource keys (standard set)

When adding a new module, add this block for the resource:

```json
"{resource}": {
  "searchPlaceholder": "...",
  "add": "Thêm ...",
  "createTitle": "Tạo ...",
  "editTitle": "Chỉnh sửa ...",
  "createSubmit": "Tạo",
  "name": "Tên ...",
  "requiredName": "Nhập tên ...",
  "minName": "Ít nhất 2 ký tự",
  "created": "Đã tạo ...",
  "updated": "Đã cập nhật ...",
  "deleted": "Đã xóa ...",
  "deleteFailed": "Không thể xóa ...",
  "deleteConfirm": "Xóa ... \"{name}\"?"
}
```

Also add `nav.{resource}` and `pages.{resource}`.

## Using translations in code

### In `<script setup>` / `<template>`

```typescript
const { t } = useI18n()

// Template
{{ t('users.add') }}

// Script
ElMessage.success(t('users.created'))
```

`useI18n()` is auto-imported by Nuxt — no explicit import needed.

### Dynamic interpolation

```typescript
t('users.deleteConfirm', { name: row.username })
```

In JSON:
```json
"deleteConfirm": "Xóa người dùng \"{name}\"?"
```

### Form validation rules (reactive to locale change)

Wrap rules in `computed` so messages update on locale switch:

```typescript
const formRules = computed<FormRules>(() => ({
  name: [
    { required: true, message: t('products.requiredName'), trigger: 'blur' },
    { min: 2, message: t('products.minName'), trigger: 'blur' }
  ]
}))
```

### ElMessageBox.confirm

```typescript
await ElMessageBox.confirm(
  t('users.deleteConfirm', { name: row.username }),
  t('common.confirmDelete'),
  {
    type: 'warning',
    confirmButtonText: t('common.delete'),
    cancelButtonText: t('common.cancel')
  }
)
```

### Page title (used by header/breadcrumb)

```typescript
useHead({ title: t('pages.products') })
```

## Reuse `common.*` keys

Before adding a resource-specific key, check if `common.*` already has it:

| Key | vi | en |
|-----|----|----|
| `common.search` | Tìm kiếm | Search |
| `common.cancel` | Hủy | Cancel |
| `common.save` | Lưu | Save |
| `common.saveChanges` | Lưu thay đổi | Save changes |
| `common.create` | Tạo | Create |
| `common.edit` | Chỉnh sửa | Edit |
| `common.delete` | Xóa | Delete |
| `common.refresh` | Làm mới | Refresh |
| `common.active` | Hoạt động | Active |
| `common.inactive` | Bị khóa | Inactive |
| `common.status` | Trạng thái | Status |
| `common.actions` | Thao tác | Actions |
| `common.confirmDelete` | Xác nhận xóa | Confirm delete |
| `common.loading` | Đang tải... | Loading... |
| `common.success` | Thành công | Success |
| `common.failed` | Thất bại | Failed |
| `common.actionFailed` | Thao tác thất bại | Action failed |

## Element Plus locale sync

Element Plus locale is synced with i18n locale in `app.vue` via `<el-config-provider>`.
When adding a new locale beyond vi/en, also add its Element Plus locale import.

## Workflow checklist

- [ ] Keys added to **both** `vi.json` and `en.json`
- [ ] `nav.{resource}` added (sidebar label)
- [ ] `pages.{resource}` added (page title)
- [ ] Standard CRUD keys added under `{resource}.*`
- [ ] Shared labels use `common.*` (not duplicated)
- [ ] All user-facing strings use `t()` — no hardcoded text
- [ ] Form rules wrapped in `computed` (reactive to locale)
- [ ] `ElMessage` / `ElMessageBox` use `t()` for all strings
- [ ] Dynamic text uses interpolation `t('key', { name })`, not concatenation
- [ ] Both locale files have identical key structure
