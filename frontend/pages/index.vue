<template>
  <div :class="styles.page">
    <section v-if="active" :class="styles.hero">
      <Transition name="hero-fade" mode="out-in">
        <div :key="active.slug" :class="styles.heroStage">
          <img
            :src="active.posterUrl || active.thumbUrl || ''"
            :alt="active.name"
            :class="styles.heroBg"
          />
          <div :class="styles.heroShade" />
          <div :class="styles.heroInner">
            <h1 :class="styles.heroTitle">{{ active.name }}</h1>
            <p :class="styles.heroMeta">
              <span v-if="active.avgRating" :class="styles.imdb">★ {{ active.avgRating }}</span>
              <span v-if="active.year">{{ active.year }}</span>
              <span v-if="active.quality">{{ active.quality }}</span>
              <span v-if="active.language">{{ active.language }}</span>
              <span v-if="active.currentEpisode">{{ active.currentEpisode }}</span>
              <span v-if="active.totalEpisodes">{{ active.totalEpisodes }}</span>
            </p>
            <p v-if="active.genres?.length" :class="styles.heroGenres">
              <span v-for="g in active.genres.slice(0, 3)" :key="g.slug">{{ g.name }}</span>
            </p>
            <p v-if="active.description" :class="styles.heroDesc">
              {{ truncate(active.description, 220) }}
            </p>
            <div :class="styles.heroActions">
              <NuxtLink :to="`/xem/${active.slug}`" :class="styles.playBtn">
                {{ t('cineva.watchNow') }}
              </NuxtLink>
              <NuxtLink :to="`/phim/${active.slug}`" :class="styles.iconBtn" :title="t('cineva.details')">
                i
              </NuxtLink>
            </div>
          </div>
        </div>
      </Transition>

      <div :class="styles.thumbStrip" role="tablist" :aria-label="t('cineva.featured')">
        <button
          v-for="(slide, idx) in slides"
          :key="slide.slug"
          type="button"
          role="tab"
          :aria-selected="idx === slideIndex"
          :class="[styles.thumb, idx === slideIndex ? styles.thumbActive : '']"
          @click="selectSlide(idx)"
        >
          <img :src="slide.thumbUrl || slide.posterUrl || ''" :alt="slide.name" />
        </button>
      </div>
    </section>

    <div :class="styles.body">
      <section v-if="topics.length" :class="styles.topics">
        <h2>{{ t('cineva.topicsInterest') }}</h2>
        <div :class="styles.topicRail">
          <NuxtLink
            v-for="topic in topics"
            :key="topic.slug"
            :to="topic.href"
            :class="[styles.topicCard, styles[`tone_${topic.tone}`] || styles.tone_slate]"
          >
            <strong>{{ topic.name }}</strong>
            <span>{{ t('cineva.viewTopic') }}</span>
          </NuxtLink>
        </div>
      </section>

      <section v-if="featured.length" :class="styles.row">
        <div :class="styles.rowHead">
          <h2>{{ t('cineva.featured') }}</h2>
        </div>
        <div :class="styles.rail">
          <FilmCard v-for="item in featured" :key="item.id" :film="item.film" />
        </div>
      </section>

      <section :class="styles.row">
        <div :class="styles.rowHead">
          <h2>{{ t('cineva.newest') }}</h2>
          <NuxtLink to="/phim">{{ t('cineva.viewAll') }}</NuxtLink>
        </div>
        <el-skeleton v-if="pending" animated :rows="3" />
        <div v-else-if="newest.length" :class="styles.rail">
          <FilmCard v-for="film in newest" :key="film.id" :film="film" />
        </div>
        <el-empty v-else :description="t('cineva.emptyFilms')" />
      </section>

      <section v-for="section in sections" :key="section.key" :class="styles.row">
        <div :class="styles.rowHead">
          <h2>{{ section.title }}</h2>
          <NuxtLink v-if="section.href" :to="section.href">{{ t('cineva.viewAll') }}</NuxtLink>
        </div>
        <div :class="styles.rail">
          <FilmCard v-for="film in section.items" :key="film.id" :film="film" />
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { FilmCardData } from '~/components/FilmCard/index.vue'
import styles from './home.module.scss'

definePageMeta({ layout: 'public' })

type HomeSlide = FilmCardData & {
  avgRating?: number
  totalEpisodes?: string | number | null
  description?: string | null
  genres?: { slug: string; name: string }[]
}

type HomeTopic = {
  slug: string
  name: string
  href: string
  tone: string
}

type HomeSection = {
  key: string
  title: string
  href?: string
  total?: number
  items: FilmCardData[]
}

type HomeResponse = {
  success: boolean
  data: {
    banners: unknown[]
    featured: { id: string | number; film: HomeSlide }[]
    slides: HomeSlide[]
    newest: FilmCardData[]
    topics: HomeTopic[]
    sections: HomeSection[]
  }
}

const { t } = useI18n()

const { data, pending } = await useAsyncData('public-home-v2', () =>
  $fetch<HomeResponse>('/api/public/home')
)

const newest = computed(() => data.value?.data?.newest || [])
const featured = computed(() => data.value?.data?.featured || [])
const topics = computed(() => data.value?.data?.topics || [])
const sections = computed(() =>
  (data.value?.data?.sections || []).filter((s) => (s.items?.length || 0) >= 6)
)
const slides = computed(() => {
  const fromApi = data.value?.data?.slides || []
  if (fromApi.length) return fromApi
  const fromFeatured = featured.value.map((f) => f.film).filter(Boolean)
  if (fromFeatured.length) return fromFeatured
  return newest.value.slice(0, 8) as HomeSlide[]
})

const slideIndex = ref(0)
const active = computed(() => slides.value[slideIndex.value] || slides.value[0] || null)

let timer: ReturnType<typeof setInterval> | null = null

function selectSlide(idx: number) {
  slideIndex.value = idx
  restartTimer()
}

function nextSlide() {
  if (slides.value.length < 2) return
  slideIndex.value = (slideIndex.value + 1) % slides.value.length
}

function restartTimer() {
  if (timer) clearInterval(timer)
  timer = setInterval(nextSlide, 6500)
}

function truncate(text: string, max: number) {
  const clean = text.replace(/<[^>]+>/g, '').trim()
  if (clean.length <= max) return clean
  return `${clean.slice(0, max).trim()}…`
}

watch(slides, (list) => {
  if (slideIndex.value >= list.length) slideIndex.value = 0
})

onMounted(() => {
  if (slides.value.length > 1) restartTimer()
})

onBeforeUnmount(() => {
  if (timer) clearInterval(timer)
})

useSeoMeta({
  title: () => `${t('app.name')} — ${t('app.tagline')}`,
  description: () => t('cineva.seoHome')
})
</script>
