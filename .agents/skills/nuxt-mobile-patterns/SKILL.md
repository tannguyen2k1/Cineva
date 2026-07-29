---
name: nuxt-mobile-patterns
description: >-
  Responsive patterns for this Nuxt 3 project: desktop DataTable vs mobile card list,
  infinite scroll, pull-to-refresh, CSS breakpoints, and mobile-first layout conventions.
  Use when building responsive pages, adding mobile views, implementing infinite scroll,
  or debugging mobile layout issues.
  Triggers on "mobile", "responsive", "infinite scroll", "pull to refresh",
  "breakpoint", "isMobile", "card list", "DataTable".
---

# Mobile & Responsive Patterns

## Responsive strategy

This project uses a **dual-view** approach:
- **Desktop** (>768px): `<DataTable>` with server-side pagination.
- **Mobile** (≤768px): Card list with client-side infinite scroll.

Detection: `appStore.isMobile` from `stores/app.ts`.
CSS breakpoint: `@media (max-width: 768px)`.

## Dual-view template

```vue
<ClientOnly>
  <!-- Desktop: DataTable -->
  <DataTable
    v-if="!appStore.isMobile"
    :data="apiResponse?.data || []"
    :total="apiResponse?.total || 0"
    :loading="pending"
    v-model:page-size="pageSize"
    v-model:current-page="currentPage"
    row-key="id"
  >
    <el-table-column prop="name" :label="t('products.name')" />
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
  <div v-else ref="mobileListRef" :class="styles.mobileList">
    <div v-for="item in mobileItems" :key="item.id" :class="styles.itemCard">
      <div :class="styles.cardHeader">
        <div :class="styles.itemInfo">
          <span :class="styles.itemName">{{ item.name }}</span>
        </div>
        <div :class="styles.cardActions">
          <el-button type="primary" link :icon="Edit" @click="openEdit(item)" />
          <el-button type="danger" link :icon="Delete" @click="onDelete(item)" />
        </div>
      </div>
      <div :class="styles.cardFooter">
        <span :class="styles.cardMeta">{{ t('common.status') }}</span>
        <el-switch :model-value="item.isActive"
          @change="(val) => onToggleActive(item, Boolean(val))" />
      </div>
    </div>
    <div v-if="pending" :class="styles.loadingMore">{{ t('common.loading') }}</div>
  </div>
</ClientOnly>
```

**Important**: Always wrap in `<ClientOnly>` to avoid SSR hydration issues with
`appStore.isMobile` (which reads `window.innerWidth`).

## Infinite scroll (mobile)

```typescript
import { useInfiniteScroll } from '@vueuse/core'

const mobileItems = ref<ItemRow[]>([])
const mobilePage = ref(1)
const hasMoreMobile = ref(true)
const mobileListRef = ref<HTMLElement | null>(null)

useInfiniteScroll(
  mobileListRef,
  () => {
    if (!pending.value && hasMoreMobile.value) {
      fetchData(true)
    }
  },
  { distance: 50 }
)
```

### Fetch logic (shared desktop + mobile)

```typescript
const fetchData = async (isLoadMore = false) => {
  pending.value = true
  try {
    const pageToFetch = appStore.isMobile
      ? (isLoadMore ? mobilePage.value + 1 : 1)
      : currentPage.value

    const res = await $fetch<any>('/api/products', {
      params: { page: pageToFetch, pageSize: pageSize.value, search: searchQuery.value }
    })

    apiResponse.value = res

    if (appStore.isMobile) {
      if (!isLoadMore) {
        mobileItems.value = res.data || []
        mobilePage.value = 1
      } else {
        mobileItems.value.push(...(res.data || []))
        mobilePage.value = pageToFetch
      }
      hasMoreMobile.value = mobileItems.value.length < (res.total || 0)
    }
  } catch (err: any) {
    error.value = err
  } finally {
    pending.value = false
  }
}
```

When search/filter changes, reset mobile state:

```typescript
watch([searchQuery, statusFilter], () => {
  currentPage.value = 1
  mobilePage.value = 1
  mobileItems.value = []
  hasMoreMobile.value = true
  fetchData()
})
```

## Pull-to-refresh

The layout provides pull-to-refresh via `providePageRefresh()` in `layouts/default.vue`.
Each page registers its refresh callback:

```typescript
import { usePageRefresh } from '~/composables/usePageRefresh'

usePageRefresh(() => fetchData())
```

This connects to `usePullToRefresh` in the layout, which renders the pull indicator
and calls the page's registered handler when the user pulls down from the top.

## CSS breakpoint patterns

All responsive styles live in `.module.scss` files. Standard breakpoint: `768px`.

### Page container

```scss
.pageContainer {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-height: 0;
  background: var(--bg-card);
}

.premiumCard {
  padding: 20px 24px;
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-height: 0;

  @media (max-width: 768px) {
    padding: 16px;
    height: auto;
    overflow: visible;
  }
}
```

### Toolbar

```scss
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 20px;
  flex-wrap: wrap;

  @media (max-width: 768px) {
    flex-direction: column;
    align-items: stretch;
  }
}

.searchInput {
  width: 320px;
  @media (max-width: 768px) { width: 100%; }
}

.filterSelect {
  width: 160px;
  @media (max-width: 768px) { width: 100%; }
}
```

### Mobile card list

```scss
.mobileList {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-bottom: 24px;
}

.itemCard {
  background: var(--bg-card);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border-color);
  box-shadow: var(--shadow-sm);
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.cardHeader {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.cardFooter {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 14px;
  border-top: 1px dashed var(--border-color);
}

.cardActions {
  display: flex;
  gap: 4px;
}

.loadingMore {
  text-align: center;
  padding: 16px;
  color: var(--text-secondary);
  font-size: 13px;
}
```

## Checklist

- [ ] Desktop uses `<DataTable>` with server-side pagination (`v-model:current-page`, `v-model:page-size`)
- [ ] Mobile uses card list with `useInfiniteScroll` on `mobileListRef`
- [ ] Both views wrapped in `<ClientOnly>` with `v-if="!appStore.isMobile"` / `v-else`
- [ ] `fetchData(isLoadMore)` handles both desktop page fetch and mobile append
- [ ] Search/filter changes reset `mobilePage`, `mobileItems`, `hasMoreMobile`
- [ ] `usePageRefresh(() => fetchData())` registered for pull-to-refresh
- [ ] CSS uses `@media (max-width: 768px)` breakpoint consistently
- [ ] Toolbar stacks vertically on mobile
- [ ] Search/filter inputs are `width: 100%` on mobile
- [ ] Mobile cards use CSS variables (`--bg-card`, `--border-color`, `--shadow-sm`, `--radius-lg`)
- [ ] Loading indicator shown at bottom of mobile list during fetch
