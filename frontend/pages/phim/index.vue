<template>
  <div :class="styles.page">
    <div :class="styles.head">
      <div>
        <p :class="styles.eyebrow">{{ t('cineva.library') }}</p>
        <h1>{{ pageTitle }}</h1>
      </div>
      <span v-if="!pending" :class="styles.count">
        {{ t('cineva.resultCount', { n: formatNumber(total, 'vi') }) }}
      </span>
    </div>

    <form :class="styles.filters" @submit.prevent="applyFilters">
      <div :class="styles.filterGrid">
        <label :class="styles.filterField">
          <span>{{ t('cineva.filterSort') }}</span>
          <el-select v-model="draft.sort" :teleported="true" popper-class="cineva-dark-select">
            <el-option :label="t('cineva.sortNewest')" value="newest" />
            <el-option :label="t('cineva.sortName')" value="name" />
            <el-option :label="t('cineva.sortYear')" value="year" />
          </el-select>
        </label>

        <label :class="styles.filterField">
          <span>{{ t('cineva.filterType') }}</span>
          <el-select
            v-model="draft.type"
            clearable
            :placeholder="t('cineva.filterAllTypes')"
            :teleported="true"
            popper-class="cineva-dark-select"
          >
            <el-option
              v-for="item in types"
              :key="item.slug"
              :label="item.name"
              :value="item.slug"
            />
          </el-select>
        </label>

        <label :class="styles.filterField">
          <span>{{ t('cineva.filterGenre') }}</span>
          <el-select
            v-model="draft.genre"
            clearable
            filterable
            :placeholder="t('cineva.filterAllGenres')"
            :teleported="true"
            popper-class="cineva-dark-select"
          >
            <el-option
              v-for="item in genres"
              :key="item.slug"
              :label="item.name"
              :value="item.slug"
            />
          </el-select>
        </label>

        <label :class="styles.filterField">
          <span>{{ t('cineva.filterYear') }}</span>
          <el-select
            v-model="draft.year"
            clearable
            :placeholder="t('cineva.filterAllYears')"
            :teleported="true"
            popper-class="cineva-dark-select"
          >
            <el-option v-for="y in years" :key="y" :label="y" :value="y" />
          </el-select>
        </label>

        <label :class="styles.filterField">
          <span>{{ t('cineva.filterCountry') }}</span>
          <el-select
            v-model="draft.country"
            clearable
            filterable
            :placeholder="t('cineva.filterAllCountries')"
            :teleported="true"
            popper-class="cineva-dark-select"
          >
            <el-option
              v-for="item in countries"
              :key="item.slug"
              :label="item.name"
              :value="item.slug"
            />
          </el-select>
        </label>
      </div>

      <div :class="styles.filterActions">
        <button type="submit" :class="styles.applyBtn">
          {{ t('cineva.applyFilters') }}
        </button>
        <button
          v-if="hasActiveFilters"
          type="button"
          :class="styles.resetBtn"
          @click="resetFilters"
        >
          {{ t('cineva.resetFilters') }}
        </button>
      </div>
    </form>

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
import { computed, reactive, watch } from 'vue'
import type { FilmCardData } from '~/components/FilmCard/index.vue'
import { formatNumber } from '~/utils/number'
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

type FilterState = {
  sort: string
  type: string
  genre: string
  year: string
  country: string
}

const { t } = useI18n()
const route = useRoute()
const router = useRouter()

const pageSize = 24
const page = computed(() => Math.max(1, Number(route.query.page) || 1))
const q = computed(() => (typeof route.query.q === 'string' ? route.query.q : ''))
const genre = computed(() => (typeof route.query.genre === 'string' ? route.query.genre : ''))
const country = computed(() =>
  typeof route.query.country === 'string' ? route.query.country : ''
)
const type = computed(() => (typeof route.query.type === 'string' ? route.query.type : ''))
const year = computed(() => (typeof route.query.year === 'string' ? route.query.year : ''))
const sort = computed(() => {
  const s = typeof route.query.sort === 'string' ? route.query.sort : 'newest'
  return ['newest', 'name', 'year'].includes(s) ? s : 'newest'
})

const draft = reactive<FilterState>({
  sort: sort.value,
  type: type.value,
  genre: genre.value,
  year: year.value,
  country: country.value
})

watch(
  [sort, type, genre, year, country],
  () => {
    draft.sort = sort.value
    draft.type = type.value
    draft.genre = genre.value
    draft.year = year.value
    draft.country = country.value
  }
)

const { data: tax } = await useAsyncData('public-taxonomies-list', () =>
  $fetch<TaxonomiesResponse>('/api/public/taxonomies')
)

const genres = computed(() => tax.value?.data?.genres || [])
const countries = computed(() => tax.value?.data?.countries || [])
const types = computed(() => tax.value?.data?.types || [])
const years = computed(() => tax.value?.data?.years || [])

const pageTitle = computed(() => {
  if (genre.value) {
    return genres.value.find((g) => g.slug === genre.value)?.name || t('cineva.movies')
  }
  if (country.value) {
    return countries.value.find((c) => c.slug === country.value)?.name || t('cineva.movies')
  }
  if (type.value) {
    return types.value.find((x) => x.slug === type.value)?.name || t('cineva.movies')
  }
  if (year.value) return t('cineva.moviesYear', { year: year.value })
  if (q.value) return t('cineva.searchResults')
  return t('cineva.movies')
})

const hasActiveFilters = computed(
  () =>
    Boolean(genre.value || country.value || type.value || year.value) ||
    sort.value !== 'newest'
)

const { data, pending } = await useAsyncData(
  'public-films',
  () =>
    $fetch<FilmsListResponse>('/api/public/films', {
      query: {
        page: page.value,
        pageSize,
        q: q.value || undefined,
        genre: genre.value || undefined,
        country: country.value || undefined,
        type: type.value || undefined,
        year: year.value || undefined,
        sort: sort.value
      }
    }),
  { watch: [page, q, genre, country, type, year, sort] }
)

const films = computed(() => data.value?.data || [])
const total = computed(() => data.value?.total || 0)

function buildQuery(extra: Record<string, string | number | undefined> = {}) {
  const query: Record<string, string | number> = {}
  if (q.value) query.q = q.value
  if (draft.genre) query.genre = draft.genre
  if (draft.country) query.country = draft.country
  if (draft.type) query.type = draft.type
  if (draft.year) query.year = draft.year
  if (draft.sort && draft.sort !== 'newest') query.sort = draft.sort
  for (const [k, v] of Object.entries(extra)) {
    if (v === undefined || v === '') delete query[k]
    else query[k] = v
  }
  return query
}

function applyFilters() {
  router.push({ path: '/phim', query: buildQuery({ page: undefined }) })
}

function resetFilters() {
  draft.sort = 'newest'
  draft.type = ''
  draft.genre = ''
  draft.year = ''
  draft.country = ''
  router.push({
    path: '/phim',
    query: q.value ? { q: q.value } : {}
  })
}

function onPage(p: number) {
  router.push({
    path: '/phim',
    query: {
      ...(q.value ? { q: q.value } : {}),
      ...(genre.value ? { genre: genre.value } : {}),
      ...(country.value ? { country: country.value } : {}),
      ...(type.value ? { type: type.value } : {}),
      ...(year.value ? { year: year.value } : {}),
      ...(sort.value !== 'newest' ? { sort: sort.value } : {}),
      ...(p > 1 ? { page: p } : {})
    }
  })
}

useSeoMeta({
  title: () => `${pageTitle.value} — ${t('app.name')}`
})
</script>
