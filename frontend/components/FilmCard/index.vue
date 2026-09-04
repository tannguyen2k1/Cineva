<template>
  <NuxtLink :to="`/phim/${film.slug}`" :class="styles.card">
    <div :class="styles.posterWrap">
      <img
        :src="film.posterUrl || film.thumbUrl || ''"
        :alt="film.name"
        loading="lazy"
        :class="styles.poster"
      />
      <span v-if="film.quality" :class="styles.badge">{{ film.quality }}</span>
      <span v-if="film.currentEpisode" :class="styles.ep">{{ film.currentEpisode }}</span>
    </div>
    <div :class="styles.meta">
      <h3 :class="styles.title">{{ film.name }}</h3>
      <p :class="styles.sub">
        <span v-if="film.year">{{ film.year }}</span>
        <span v-if="film.language"> · {{ film.language }}</span>
      </p>
    </div>
  </NuxtLink>
</template>

<script setup lang="ts">
import styles from './FilmCard.module.scss'

export type FilmCardData = {
  id?: number | string
  slug: string
  name: string
  posterUrl?: string | null
  thumbUrl?: string | null
  year?: string | null
  quality?: string | null
  language?: string | null
  currentEpisode?: string | null
}

defineProps<{
  film: FilmCardData
}>()
</script>
