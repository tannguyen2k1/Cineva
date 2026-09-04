<template>
  <div :class="styles.page">
    <h1>{{ t('cineva.watchlist') }}</h1>
    <el-skeleton v-if="pending" animated :rows="4" />
    <div v-else-if="films.length" :class="styles.grid">
      <FilmCard v-for="film in films" :key="film.id" :film="film" />
    </div>
    <el-empty v-else :description="t('cineva.emptyWatchlist')" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import styles from '../phim/phim.module.scss'

definePageMeta({ layout: 'public' })

const { t } = useI18n()

const { data, pending } = await useAsyncData('my-watchlist', () =>
  useApiFetch('/api/me/watchlist', { query: { page: 1, pageSize: 48 } })
)

const films = computed(() => data.value?.data || [])

useSeoMeta({
  title: () => `${t('cineva.watchlist')} — ${t('app.name')}`
})
</script>
