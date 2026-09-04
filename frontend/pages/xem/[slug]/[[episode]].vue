<template>
  <div :class="styles.page">
    <div :class="styles.toolbar">
      <NuxtLink :to="`/phim/${slug}`" :class="styles.back">← {{ film?.name || slug }}</NuxtLink>
      <div v-if="servers.length" :class="styles.serverSelect">
        <el-select
          v-model="serverName"
          size="default"
          :class="styles.select"
          :teleported="true"
          popper-class="cineva-dark-select"
          style="min-width: 180px"
        >
          <el-option
            v-for="s in servers"
            :key="s.serverName"
            :label="s.serverName"
            :value="s.serverName"
          />
        </el-select>
      </div>
    </div>

    <div :class="styles.player">
      <iframe
        v-if="embedUrl"
        :src="embedUrl"
        :title="film?.name || 'player'"
        allowfullscreen
        allow="autoplay; fullscreen; picture-in-picture"
        :class="styles.frame"
      />
      <el-empty v-else :description="t('cineva.noEmbed')" />
    </div>

    <div v-if="episodes.length" :class="styles.eps">
      <h2>{{ t('cineva.episodes') }}</h2>
      <div :class="styles.epGrid">
        <NuxtLink
          v-for="ep in episodes"
          :key="ep.slug"
          :to="`/xem/${slug}/${ep.slug}?server=${encodeURIComponent(serverName)}`"
          :class="[styles.epBtn, ep.slug === currentEpisode ? styles.active : '']"
        >
          {{ ep.name }}
        </NuxtLink>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import styles from './watch.module.scss'

type EpisodeItem = { name: string; slug: string; embed: string }
type EpisodeServer = { serverName: string; items: EpisodeItem[] }
type FilmDetail = {
  name: string
  slug: string
  episodes?: EpisodeServer[]
}
type FilmDetailResponse = { success: boolean; data: FilmDetail }

definePageMeta({ layout: 'public' })

const { t } = useI18n()
const route = useRoute()
const authStore = useAuthStore()

const slug = computed(() => String(route.params.slug || ''))
const episodeParam = computed(() =>
  route.params.episode ? String(route.params.episode) : ''
)

const { data } = await useAsyncData(
  () => `watch-${slug.value}`,
  () => $fetch<FilmDetailResponse>(`/api/public/films/${slug.value}`),
  { watch: [slug] }
)

const film = computed(() => data.value?.data ?? null)
const servers = computed(() => film.value?.episodes ?? [])

const serverName = ref(
  typeof route.query.server === 'string'
    ? route.query.server
    : servers.value[0]?.serverName || ''
)

watch(
  servers,
  (list) => {
    if (!list.length) return
    if (!list.some((s) => s.serverName === serverName.value)) {
      serverName.value = list[0]?.serverName || ''
    }
  },
  { immediate: true }
)

const episodes = computed(() => {
  const server = servers.value.find((s) => s.serverName === serverName.value)
  return server?.items ?? []
})

const currentEpisode = computed(() => {
  if (episodeParam.value) return episodeParam.value
  return episodes.value[0]?.slug || ''
})

const embedUrl = computed(() => {
  const ep = episodes.value.find((e) => e.slug === currentEpisode.value)
  return ep?.embed || ''
})

watch(
  [currentEpisode, serverName, () => authStore.isLoggedIn],
  async ([ep, server, loggedIn]) => {
    if (!loggedIn || !ep || !slug.value) return
    const item = episodes.value.find((e) => e.slug === ep)
    try {
      await useApiFetch('/api/me/progress', {
        method: 'PUT',
        body: {
          slug: slug.value,
          episodeSlug: ep,
          episodeName: item?.name || ep,
          serverName: server
        }
      })
    } catch {
      // ignore progress errors while watching
    }
  },
  { immediate: true }
)

useSeoMeta({
  title: () =>
    film.value
      ? `${t('cineva.watching')}: ${film.value.name} — ${t('app.name')}`
      : t('app.name')
})
</script>
