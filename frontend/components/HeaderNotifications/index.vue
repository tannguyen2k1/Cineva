<template>
  <div ref="rootEl" :class="styles.root">
    <button
      type="button"
      :class="styles.trigger"
      :aria-label="t('cineva.notifications')"
      :aria-expanded="open"
      @click="toggle"
    >
      <el-icon :size="18"><Bell /></el-icon>
      <span v-if="unreadCount > 0" :class="styles.badge">
        {{ unreadCount > 99 ? '99+' : unreadCount }}
      </span>
    </button>

    <div v-if="open" :class="styles.panel" role="menu">
      <div :class="styles.head">
        <strong>{{ t('cineva.notifications') }}</strong>
        <button
          type="button"
          :class="styles.markAll"
          :disabled="!unreadCount || marking"
          @click="markAll"
        >
          {{ t('cineva.markAllRead') }}
        </button>
      </div>

      <div :class="styles.list">
        <p v-if="loading" :class="styles.status">{{ t('common.loading') }}</p>
        <template v-else-if="items.length">
          <button
            v-for="n in items"
            :key="n.id"
            type="button"
            :class="[styles.item, !n.isRead ? styles.unread : '']"
            @click="openItem(n)"
          >
            <img
              v-if="n.film?.posterUrl || n.film?.thumbUrl"
              :src="n.film.posterUrl || n.film.thumbUrl || ''"
              alt=""
              :class="styles.thumb"
            />
            <span v-else :class="styles.dot">
              {{ (n.actor?.fullName || n.actor?.username || '?').slice(0, 1).toUpperCase() }}
            </span>
            <div :class="styles.meta">
              <p :class="styles.title">{{ n.title }}</p>
              <p v-if="n.body" :class="styles.body">{{ n.body }}</p>
              <p v-if="n.createdAt" :class="styles.time">{{ formatDateTime(n.createdAt) }}</p>
            </div>
          </button>
        </template>
        <p v-else :class="styles.empty">{{ t('cineva.emptyNotifications') }}</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Bell } from '@element-plus/icons-vue'
import { onClickOutside } from '@vueuse/core'
import styles from './HeaderNotifications.module.scss'

type NotifItem = {
  id: string
  kind: string
  title: string
  body?: string | null
  linkUrl?: string | null
  isRead: boolean
  createdAt?: string
  actor?: { username?: string; fullName?: string | null; avatar?: string | null } | null
  film?: {
    slug: string
    name: string
    thumbUrl?: string | null
    posterUrl?: string | null
  } | null
}

type ListResponse = {
  success: boolean
  data: NotifItem[]
  unreadCount?: number
}

const { t } = useI18n()
const { formatDateTime } = useDateTime()
const router = useRouter()
const authStore = useAuthStore()

const rootEl = ref<HTMLElement | null>(null)
const open = ref(false)
const loading = ref(false)
const marking = ref(false)
const items = ref<NotifItem[]>([])
const unreadCount = ref(0)

onClickOutside(rootEl, () => {
  open.value = false
})

async function refreshUnread() {
  if (!authStore.isLoggedIn) {
    unreadCount.value = 0
    return
  }
  try {
    const res = await useApiFetch('/api/me/notifications/unread-count')
    unreadCount.value = res?.data?.unreadCount || 0
  } catch {
    unreadCount.value = 0
  }
}

async function loadList() {
  loading.value = true
  try {
    const res = await useApiFetch('/api/me/notifications', {
      query: { page: 1, pageSize: 20 }
    }) as ListResponse
    items.value = res?.data || []
    if (typeof res?.unreadCount === 'number') unreadCount.value = res.unreadCount
  } catch {
    items.value = []
  } finally {
    loading.value = false
  }
}

async function toggle() {
  open.value = !open.value
  if (open.value) await loadList()
}

async function markAll() {
  marking.value = true
  try {
    await useApiFetch('/api/me/notifications/read-all', { method: 'POST' })
    unreadCount.value = 0
    items.value = items.value.map((n) => ({ ...n, isRead: true }))
  } finally {
    marking.value = false
  }
}

async function openItem(n: NotifItem) {
  if (!n.isRead) {
    try {
      await useApiFetch(`/api/me/notifications/${n.id}/read`, { method: 'PUT' })
      n.isRead = true
      unreadCount.value = Math.max(0, unreadCount.value - 1)
    } catch {
      // ignore
    }
  }
  open.value = false
  if (n.linkUrl) await router.push(n.linkUrl)
}

watch(
  () => authStore.isLoggedIn,
  (ok) => {
    if (ok) refreshUnread()
    else {
      unreadCount.value = 0
      items.value = []
      open.value = false
    }
  },
  { immediate: true }
)

// Light poll while logged in
let timer: ReturnType<typeof setInterval> | null = null
onMounted(() => {
  timer = setInterval(() => {
    if (authStore.isLoggedIn && !open.value) refreshUnread()
  }, 60000)
})
onBeforeUnmount(() => {
  if (timer) clearInterval(timer)
})
</script>
