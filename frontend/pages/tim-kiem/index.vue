<template>
  <div :class="styles.page">
    <h1>{{ t('cineva.searchResults') }}: “{{ q }}”</h1>
    <el-skeleton v-if="pending" animated :rows="5" />
    <div v-else-if="films.length" :class="styles.grid">
      <FilmCard v-for="film in films" :key="film.id" :film="film" />
    </div>
    <el-empty v-else :description="t('cineva.emptyFilms')" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { FilmCardData } from '~/components/FilmCard/index.vue'
import styles from '../phim/phim.module.scss'

definePageMeta({ layout: 'public' })

type FilmsListResponse = {
  success: boolean
  data: FilmCardData[]
  total?: number
}

const { t } = useI18n()
const route = useRoute()
const q = computed(() => (typeof route.query.q === 'string' ? route.query.q : ''))

const { data, pending } = await useAsyncData(
  () => `search-${q.value}`,
  () =>
    $fetch<FilmsListResponse>('/api/public/films', {
      query: { q: q.value || undefined, page: 1, pageSize: 48 }
    }),
  { watch: [q] }
)

const films = computed(() => data.value?.data || [])

useSeoMeta({
  title: () => `${t('cineva.searchResults')} — ${t('app.name')}`
})
</script>
