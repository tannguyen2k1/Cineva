<template>
  <div
    ref="rootEl"
    :class="[styles.root, expanded && styles.expanded]"
    :data-expanded="expanded ? 'true' : undefined"
  >
    <button
      type="button"
      :class="styles.iconBtn"
      :aria-label="t('cineva.search')"
      @click="expand"
    >
      <el-icon :size="22"><Search /></el-icon>
    </button>

    <button
      v-if="isCompact"
      type="button"
      :class="styles.backdrop"
      tabindex="-1"
      aria-hidden="true"
      @click="collapse"
    />

    <form :class="styles.field" @submit.prevent="goSearch">
      <el-icon :class="styles.icon"><Search /></el-icon>
      <input
        ref="inputEl"
        v-model="keyword"
        type="search"
        :placeholder="t('cineva.searchPlaceholder')"
        :class="styles.input"
        autocomplete="off"
        role="combobox"
        aria-autocomplete="list"
        :aria-expanded="open"
        @focus="onFocus"
        @keydown="onKeydown"
      />
      <button
        v-if="keyword"
        type="button"
        :class="styles.clear"
        :aria-label="t('common.clear')"
        @click="clear"
      >
        <el-icon><Close /></el-icon>
      </button>
      <button
        type="button"
        :class="styles.cancel"
        @click="collapse"
      >
        {{ t('common.cancel') }}
      </button>
    </form>

    <div v-if="open && (!isCompact || expanded)" :class="styles.panel" role="listbox">
      <p v-if="loading" :class="styles.status">{{ t('common.loading') }}</p>
      <template v-else-if="suggestions.length">
        <NuxtLink
          v-for="(film, idx) in suggestions"
          :key="film.slug"
          :to="`/phim/${film.slug}`"
          :class="[styles.item, idx === activeIndex ? styles.active : '']"
          role="option"
          @click="close"
          @mouseenter="activeIndex = idx"
        >
          <img
            :src="film.posterUrl || film.thumbUrl || ''"
            :alt="film.name"
            :class="styles.thumb"
            loading="lazy"
          />
          <div :class="styles.meta">
            <p :class="styles.title">{{ film.name }}</p>
            <p :class="styles.sub">
              <span v-if="film.year">{{ film.year }}</span>
              <span v-if="film.currentEpisode"> · {{ film.currentEpisode }}</span>
              <span v-else-if="film.originalName"> · {{ film.originalName }}</span>
            </p>
          </div>
        </NuxtLink>
        <NuxtLink
          :to="{ path: '/tim-kiem', query: { q: keyword.trim() } }"
          :class="styles.footer"
          @click="close"
        >
          {{ t('cineva.viewAllResults') }}
        </NuxtLink>
      </template>
      <p v-else-if="debouncedQ" :class="styles.status">{{ t('cineva.emptyFilms') }}</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Close, Search } from '@element-plus/icons-vue'
import { onClickOutside, useMediaQuery, watchDebounced } from '@vueuse/core'
import styles from './HeaderSearch.module.scss'

type Suggestion = {
  slug: string
  name: string
  originalName?: string | null
  posterUrl?: string | null
  thumbUrl?: string | null
  year?: string | null
  currentEpisode?: string | null
}

type FilmsListResponse = {
  success: boolean
  data: Suggestion[]
}

const { t } = useI18n()
const route = useRoute()
const router = useRouter()

const rootEl = ref<HTMLElement | null>(null)
const inputEl = ref<HTMLInputElement | null>(null)
const keyword = ref(typeof route.query.q === 'string' ? route.query.q : '')
const debouncedQ = ref('')
const suggestions = ref<Suggestion[]>([])
const loading = ref(false)
const open = ref(false)
const activeIndex = ref(-1)
const expanded = ref(false)
const isCompact = useMediaQuery('(max-width: 1099px)')
let requestId = 0
let focusTimer: ReturnType<typeof setTimeout> | null = null

watch(isCompact, (compact) => {
  if (!compact) expanded.value = false
})

watch(
  () => route.query.q,
  (q) => {
    if (typeof q === 'string' && q !== keyword.value) keyword.value = q
  }
)

watchDebounced(
  keyword,
  (value) => {
    debouncedQ.value = value.trim()
  },
  { debounce: 350 }
)

watch(debouncedQ, async (q) => {
  activeIndex.value = -1
  if (!q) {
    suggestions.value = []
    open.value = false
    return
  }
  const id = ++requestId
  loading.value = true
  open.value = true
  try {
    const res = await $fetch<FilmsListResponse>('/api/public/films', {
      query: { q, page: 1, pageSize: 8 }
    })
    if (id !== requestId) return
    suggestions.value = res.data || []
  } catch {
    if (id !== requestId) return
    suggestions.value = []
  } finally {
    if (id === requestId) loading.value = false
  }
})

onClickOutside(rootEl, (event) => {
  const target = event.target as HTMLElement | null
  if (target?.closest?.(`.${styles.backdrop}`)) return
  open.value = false
  if (isCompact.value && expanded.value && !keyword.value.trim()) {
    collapse()
  }
})

onBeforeUnmount(() => {
  if (focusTimer) clearTimeout(focusTimer)
})

function expand() {
  expanded.value = true
  if (focusTimer) clearTimeout(focusTimer)
  focusTimer = setTimeout(() => {
    inputEl.value?.focus()
  }, 220)
}

function collapse() {
  if (focusTimer) clearTimeout(focusTimer)
  inputEl.value?.blur()
  expanded.value = false
  open.value = false
  activeIndex.value = -1
}

function onFocus() {
  if (debouncedQ.value) open.value = true
}

function close() {
  open.value = false
  activeIndex.value = -1
  if (isCompact.value) collapse()
}

function clear() {
  keyword.value = ''
  debouncedQ.value = ''
  suggestions.value = []
  open.value = false
  inputEl.value?.focus()
}

function goSearch() {
  const q = keyword.value.trim()
  close()
  router.push(q ? { path: '/tim-kiem', query: { q } } : '/phim')
}

function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape') {
    if (isCompact.value && expanded.value) {
      e.preventDefault()
      collapse()
      return
    }
    close()
    return
  }
  if (!open.value || !suggestions.value.length) return
  if (e.key === 'ArrowDown') {
    e.preventDefault()
    activeIndex.value = (activeIndex.value + 1) % suggestions.value.length
  } else if (e.key === 'ArrowUp') {
    e.preventDefault()
    activeIndex.value =
      activeIndex.value <= 0 ? suggestions.value.length - 1 : activeIndex.value - 1
  } else if (e.key === 'Enter' && activeIndex.value >= 0) {
    e.preventDefault()
    const film = suggestions.value[activeIndex.value]
    if (film) {
      close()
      router.push(`/phim/${film.slug}`)
    }
  }
}
</script>
