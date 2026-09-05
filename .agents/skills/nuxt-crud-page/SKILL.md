---
name: nuxt-crud-page
description: >-
  Template for creating CRUD listing pages in the Nuxt frontend of this monorepo.
  Covers desktop DataTable + mobile card list with infinite scroll,
  search/filter toolbar, create/edit dialog, status toggle, delete confirm,
  CSS Modules, and i18n integration.
  Use when creating a new management page, adding a listing view, or scaffolding
  a CRUD interface. Triggers on "new page", "create page", "CRUD page",
  "listing page", "management page", "add module".
---

# Creating CRUD Pages

## File structure

```
frontend/pages/{section}/{resource}/
├── index.vue               # Page component
└── {resource}.module.scss   # CSS Modules styles
```

API calls use relative `/api/{resource}` (Nuxt proxies to FastAPI). Backend endpoints: see `skills/fastapi-endpoint`.

## DateTime display

API returns UTC (`...Z`). Always format via:

```typescript
import { useDateTime } from '~/composables/useDateTime'

const { formatDate, formatDateTime, localDayStartToIso, localDayEndToIso } = useDateTime()
// table: {{ formatDateTime(row.createdAt) }}
// filter: params.startDate = localDayStartToIso(day)
```

Do **not** use `new Date(row.createdAt).toLocaleString(...)` in pages.

## Script setup structure

```typescript
<script setup lang="ts">
import styles from './{resource}.module.scss'
import { ref, reactive, computed, watch, onMounted } from 'vue'
import { Search, Plus, Edit, Delete } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import { useAuthStore } from '~/stores/auth'
import { useAppStore } from '~/stores/app'
import { useInfiniteScroll } from '@vueuse/core'

// --- Interfaces ---
interface ItemRow {
  id: string
  name: string
  isActive: boolean
  createdAt: string
}

// --- State ---
const { t } = useI18n()
const appStore = useAppStore()

const currentPage = ref(1)
const pageSize = ref(10)
const searchQuery = ref('')
const statusFilter = ref('')
const pending = ref(false)
const error = ref<any>(null)
const apiResponse = ref<{ data: ItemRow[]; total: number } | null>(null)

// Mobile infinite scroll
const mobilePage = ref(1)
const mobileItems = ref<ItemRow[]>([])
const mobileHasMore = ref(true)

// Dialog
const dialogVisible = ref(false)
const isEdit = ref(false)
const saving = ref(false)
const formRef = ref<FormInstance>()
const form = reactive({ id: '', name: '', isActive: true })

// --- Fetch ---
const fetchData = async (isLoadMore = false) => {
  pending.value = true
  error.value = null
  try {
    const pg = appStore.isMobile ? (isLoadMore ? mobilePage.value + 1 : 1) : currentPage.value
    const params: Record<string, any> = { page: pg, pageSize: pageSize.value }
    if (searchQuery.value) params.search = searchQuery.value
    if (statusFilter.value) params.status = statusFilter.value

    const res = await $fetch<any>('/api/{resource}', { params })
    // ...handle response, append mobile items or set apiResponse
  } catch (err: any) {
    error.value = err
  } finally {
    pending.value = false
  }
}

// --- Infinite scroll (mobile) ---
const appScrollEl = inject<Ref<HTMLElement | null>>('appScrollEl', ref(null))
useInfiniteScroll(appScrollEl, () => {
  if (!appStore.isMobile || !mobileHasMore.value || pending.value) return
  fetchData(true)
}, { distance: 200 })

// --- Search debounce ---
watch([searchQuery, statusFilter], () => {
  currentPage.value = 1
  mobilePage.value = 1
  mobileItems.value = []
  mobileHasMore.value = true
  fetchData()
}, { debounce: 300 })

// --- CRUD handlers ---
// openCreate, openEdit, onSubmit, onDelete, onToggleActive ...

// --- Lifecycle ---
onMounted(() => fetchData())
usePageRefresh(() => fetchData())
</script>
```

## Template structure

```vue
<template>
  <div :class="styles.pageContainer">
    <!-- Error alert -->
    <el-alert v-if="error" type="error" :title="error.message" show-icon />

    <div :class="styles.premiumCard">
      <!-- Toolbar: search + filter + add button -->
      <div :class="styles.toolbar">
        <div :class="styles.filterSection">
          <el-input v-model="searchQuery" :placeholder="t('{resource}.searchPlaceholder')"
            :prefix-icon="Search" clearable />
          <el-select v-model="statusFilter" :placeholder="t('common.status')" clearable>
            <el-option :label="t('common.active')" value="active" />
            <el-option :label="t('common.inactive')" value="inactive" />
          </el-select>
        </div>
        <el-button type="primary" :icon="Plus" @click="openCreate">
          {{ t('{resource}.add') }}
        </el-button>
      </div>

      <ClientOnly>
        <!-- Desktop: DataTable -->
        <DataTable v-if="!appStore.isMobile" :data="apiResponse?.data || []"
          :total="apiResponse?.total || 0" :loading="pending"
          v-model:page-size="pageSize" v-model:current-page="currentPage">
          <el-table-column prop="name" :label="t('{resource}.name')" />
          <el-table-column prop="isActive" :label="t('common.status')" width="120">
            <template #default="scope">
              <el-switch :model-value="scope.row.isActive"
                @change="(val) => onToggleActive(scope.row, Boolean(val))" />
            </template>
          </el-table-column>
          <el-table-column :label="t('common.actions')" width="120" align="right">
            <template #default="scope">
              <el-button type="primary" link :icon="Edit" @click="openEdit(scope.row)" />
              <el-button type="danger" link :icon="Delete" @click="onDelete(scope.row)" />
            </template>
          </el-table-column>
        </DataTable>

        <!-- Mobile: card list -->
        <div v-else :class="styles.mobileList">
          <div v-for="item in mobileItems" :key="item.id" :class="styles.itemCard">
            <!-- card content -->
          </div>
          <div v-if="pending" :class="styles.loadingMore">{{ t('common.loading') }}</div>
        </div>
      </ClientOnly>
    </div>

    <!-- Create/Edit dialog -->
    <el-dialog v-model="dialogVisible"
      :title="isEdit ? t('{resource}.editTitle') : t('{resource}.createTitle')"
      width="480px" destroy-on-close @closed="resetForm">
      <el-form ref="formRef" :model="form" :rules="formRules"
        label-position="top" @submit.prevent>
        <!-- form items -->
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">{{ t('common.cancel') }}</el-button>
        <el-button type="primary" :loading="saving" @click="onSubmit">
          {{ isEdit ? t('common.saveChanges') : t('{resource}.createSubmit') }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>
```

## i18n keys to add

Add to `i18n/locales/vi.json`:

```json
"{resource}": {
  "title": "...",
  "add": "Thêm ...",
  "createTitle": "Tạo ...",
  "editTitle": "Sửa ...",
  "createSubmit": "Tạo",
  "searchPlaceholder": "Tìm kiếm...",
  "deleteConfirm": "Xóa \"{name}\"?",
  "deleteSuccess": "Đã xóa",
  "deleteFailed": "Không thể xóa",
  "name": "Tên",
  "minName": "Tên phải có ít nhất 2 ký tự"
}
```

## Checklist

- [ ] Page at `pages/{section}/{resource}/index.vue`
- [ ] Styles at `pages/{section}/{resource}/{resource}.module.scss` (CSS Modules, camelCase)
- [ ] Desktop view uses `<DataTable>` component with pagination
- [ ] Mobile view uses card list with `useInfiniteScroll` on `appScrollEl`
- [ ] Wrapped in `<ClientOnly>` to avoid SSR hydration issues
- [ ] Search/filter with debounced `watch`
- [ ] Create/edit dialog with `el-form` + validation rules
- [ ] Delete uses `ElMessageBox.confirm` then soft-delete API
- [ ] Status toggle via `el-switch` calling PUT API
- [ ] All user-facing strings use `t()` from `useI18n()`
- [ ] Datetime columns use `useDateTime()` (`formatDate` / `formatDateTime`)
- [ ] i18n keys added to `vi.json`
- [ ] `usePageRefresh(() => fetchData())` for pull-to-refresh support
- [ ] Corresponding API endpoints exist (GET list, POST create, PUT update, DELETE)
