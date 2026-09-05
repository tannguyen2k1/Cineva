<template>
  <div :class="styles.page">
    <header :class="styles.head">
      <div>
        <h1>{{ t('cineva.watched') }}</h1>
        <p :class="styles.subhead">{{ t('cineva.watchedHint') }}</p>
      </div>
      <span v-if="items.length" :class="styles.count">
        {{ t('cineva.watchedCount', { n: items.length }) }}
      </span>
    </header>

    <el-skeleton v-if="pending" animated :rows="5" />

    <div v-else-if="items.length" :class="styles.grid">
      <NuxtLink
        v-for="item in items"
        :key="item.slug"
        :to="continueLink(item)"
        :class="styles.card"
      >
        <div :class="styles.poster">
          <img
            :src="item.film.posterUrl || item.film.thumbUrl || ''"
            :alt="item.film.name"
            loading="lazy"
          />
          <div :class="styles.shade" aria-hidden="true" />
          <span v-if="episodeLabel(item)" :class="styles.epBadge">
            {{ episodeLabel(item) }}
          </span>
          <span :class="styles.play" aria-hidden="true">
            <el-icon :size="22"><VideoPlay /></el-icon>
          </span>
        </div>

        <div :class="styles.meta">
          <h3>{{ item.film.name }}</h3>
          <p :class="styles.continue">
            {{ t('cineva.continueWatch') }}
            <span v-if="episodeLabel(item)">· {{ episodeLabel(item) }}</span>
          </p>
          <p v-if="item.film.year || item.film.quality" :class="styles.detail">
            <span v-if="item.film.year">{{ item.film.year }}</span>
            <span v-if="item.film.quality"> · {{ item.film.quality }}</span>
          </p>
        </div>
      </NuxtLink>
    </div>

    <div v-else :class="styles.empty">
      <el-empty :description="t('cineva.emptyWatched')" />
      <NuxtLink to="/phim" :class="styles.emptyCta">{{ t('cineva.browseFilms') }}</NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { VideoPlay } from '@element-plus/icons-vue'
import type { FilmCardData } from '~/components/FilmCard/index.vue'
import styles from './da-xem.module.scss'

definePageMeta({ layout: 'public' })

type ContinueItem = {
  slug: string
  episodeSlug?: string
  episodeName?: string | null
  serverName?: string | null
  film: FilmCardData
}

const { t } = useI18n()

const { data, pending } = await useAsyncData('my-continue', () =>
  useApiFetch('/api/me/continue')
)

const items = computed(() => (data.value?.data || []) as ContinueItem[])

function continueLink(item: ContinueItem) {
  const base = item.episodeSlug
    ? `/xem/${item.slug}/${item.episodeSlug}`
    : `/xem/${item.slug}`
  if (!item.serverName) return base
  return `${base}?server=${encodeURIComponent(item.serverName)}`
}

function episodeLabel(item: ContinueItem) {
  const raw = (item.episodeName || '').trim()
  if (!raw) return ''
  if (/^\d+$/.test(raw)) return t('cineva.episodeN', { n: raw })
  return raw
}

useSeoMeta({
  title: () => `${t('cineva.watched')} — ${t('app.name')}`,
  robots: 'noindex, nofollow'
})
</script>
