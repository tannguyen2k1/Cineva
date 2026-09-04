<template>
  <div :class="styles.page">
    <div :class="styles.head">
      <h1>{{ pageTitle }}</h1>
      <el-input
        v-model="q"
        clearable
        :class="styles.search"
        :placeholder="t('cineva.searchPlaceholder')"
        @clear="reload"
        @keyup.enter="reload"
      />
    </div>

    <el-skeleton v-if="pending" animated :rows="6" />
    <template v-else>
      <div v-if="films.length" :class="styles.grid">
        <FilmCard v-for="film in films" :key="film.id" :film="film" />
      </div>
      <el-empty v-else :description="t('cineva.emptyFilms')" />

      <div v-if="total > pageSize" :class="styles.pager">
        <el-pagination
          layout="prev, pager, next"
          :page-size="pageSize"
          :current-page="page"
          :total="total"
          @current-change="onPage"
        />
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { FilmCardData } from '~/components/FilmCard/index.vue'
import styles from './phim.module.scss'

definePageMeta({ layout: 'public' })

type TaxonomyItem = { slug: string; name: string }
type TaxonomiesResponse = {
  success: boolean
  data: {
    genres: TaxonomyItem[]
    countries: TaxonomyItem[]
    types: TaxonomyItem[]
    years?: string[]
  }
}
type FilmsListResponse = {
  success: boolean
  data: FilmCardData[]
  total: number
  page?: number
  pageSize?: number
}

const { t } = useI18n()
const route = useRoute()
const router = useRouter()

const pageSize = 24
const page = computed(() => Math.max(1, Number(route.query.page) || 1))
const q = ref(typeof route.query.q === 'string' ? route.query.q : '')
const genre = computed(() => (typeof route.query.genre === 'string' ? route.query.genre : undefined))
const country = computed(() =>
  typeof route.query.country === 'string' ? route.query.country : undefined
)
const type = computed(() => (typeof route.query.type === 'string' ? route.query.type : undefined))

const { data: tax } = await useAsyncData('public-taxonomies-list', () =>
  $fetch<TaxonomiesResponse>('/api/public/taxonomies')
)

const pageTitle = computed(() => {
  const genres = tax.value?.data?.genres || []
  const countries = tax.value?.data?.countries || []
  const types = tax.value?.data?.types || []
  if (genre.value) {
    return genres.find((g) => g.slug === genre.value)?.name || t('cineva.movies')
  }
  if (country.value) {
    return countries.find((c) => c.slug === country.value)?.name || t('cineva.movies')
  }
  if (type.value) {
    return types.find((x) => x.slug === type.value)?.name || t('cineva.movies')
  }
  return t('cineva.movies')
})

const { data, pending, refresh } = await useAsyncData(
  'public-films',
  () =>
    $fetch<FilmsListResponse>('/api/public/films', {
      query: {
        page: page.value,
        pageSize,
        q: q.value || undefined,
        genre: genre.value,
        country: country.value,
        type: type.value
      }
    }),
  { watch: [page, genre, country, type] }
)

const films = computed(() => data.value?.data || [])
const total = computed(() => data.value?.total || 0)

function filterQuery(extra: Record<string, string | number | undefined> = {}) {
  return {
    ...(q.value ? { q: q.value } : {}),
    ...(genre.value ? { genre: genre.value } : {}),
    ...(country.value ? { country: country.value } : {}),
    ...(type.value ? { type: type.value } : {}),
    ...extra
  }
}

function reload() {
  router.push({
    path: '/phim',
    query: filterQuery({ page: 1 })
  })
  refresh()
}

function onPage(p: number) {
  router.push({
    path: '/phim',
    query: filterQuery({ page: p })
  })
}

watch(
  () => route.query.q,
  (val) => {
    q.value = typeof val === 'string' ? val : ''
  }
)

useSeoMeta({
  title: () => `${pageTitle.value} — ${t('app.name')}`
})
</script>
