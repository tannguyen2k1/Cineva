<template>
  <div v-if="film" :class="styles.page">
    <div :class="styles.top">
      <img
        :src="film.posterUrl || film.thumbUrl || ''"
        :alt="film.name"
        :class="styles.poster"
      />
      <div :class="styles.info">
        <h1>{{ film.name }}</h1>
        <p v-if="film.originalName" :class="styles.original">{{ film.originalName }}</p>
        <div :class="styles.chips">
          <span v-if="film.year">{{ film.year }}</span>
          <span v-if="film.quality">{{ film.quality }}</span>
          <span v-if="film.language">{{ film.language }}</span>
          <span v-if="film.currentEpisode">{{ film.currentEpisode }}</span>
        </div>
        <p :class="styles.rating">
          ★ {{ film.avgRating || 0 }}
          <small>({{ film.ratingCount || 0 }})</small>
        </p>
        <div :class="styles.actions">
          <NuxtLink :to="watchLink" :class="styles.primaryBtn">{{ t('cineva.watchNow') }}</NuxtLink>
          <el-button v-if="authStore.isLoggedIn" @click="toggleWatchlist">
            {{ film.inWatchlist ? t('cineva.removeWatchlist') : t('cineva.addWatchlist') }}
          </el-button>
        </div>
        <p v-if="film.director"><strong>{{ t('cineva.director') }}:</strong> {{ film.director }}</p>
        <p v-if="film.casts"><strong>{{ t('cineva.casts') }}:</strong> {{ film.casts }}</p>
        <div v-if="film.genres?.length" :class="styles.tags">
          <NuxtLink
            v-for="g in film.genres"
            :key="g.slug"
            :to="`/phim?genre=${g.slug}`"
          >
            {{ g.name }}
          </NuxtLink>
        </div>
      </div>
    </div>

    <section :class="styles.block">
      <h2>{{ t('cineva.synopsis') }}</h2>
      <div :class="styles.desc" v-html="film.description || t('cineva.noDescription')" />
    </section>

    <section v-if="film.episodes?.length" :class="styles.block">
      <h2>{{ t('cineva.episodes') }}</h2>
      <div v-for="server in film.episodes" :key="server.serverName" :class="styles.server">
        <h3>{{ server.serverName }}</h3>
        <div :class="styles.epGrid">
          <NuxtLink
            v-for="ep in server.items"
            :key="ep.slug"
            :to="`/xem/${film.slug}/${ep.slug}?server=${encodeURIComponent(server.serverName)}`"
            :class="styles.epBtn"
          >
            {{ ep.name }}
          </NuxtLink>
        </div>
      </div>
    </section>

    <section :class="styles.block">
      <h2>{{ t('cineva.comments') }}</h2>
      <div v-if="authStore.isLoggedIn" :class="styles.commentForm">
        <el-input
          v-model="commentBody"
          type="textarea"
          :rows="3"
          :placeholder="t('cineva.commentPlaceholder')"
          maxlength="2000"
          show-word-limit
        />
        <el-button type="primary" :loading="commenting" @click="submitComment">
          {{ t('cineva.postComment') }}
        </el-button>
      </div>
      <p v-else :class="styles.loginHint">
        <NuxtLink to="/login">{{ t('login.title') }}</NuxtLink> {{ t('cineva.toComment') }}
      </p>
      <div v-if="comments.length" :class="styles.commentList">
        <article v-for="c in comments" :key="c.id" :class="styles.commentItem">
          <strong>{{ c.username }}</strong>
          <p>{{ c.body }}</p>
        </article>
      </div>
      <el-empty v-else :description="t('cineva.noComments')" :image-size="64" />
    </section>
  </div>
  <el-empty v-else-if="!pending" :description="t('cineva.notFound')" />
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { ElMessage } from 'element-plus'
import styles from './slug.module.scss'

definePageMeta({ layout: 'public' })

type EpisodeItem = { name: string; slug: string; embed?: string }
type EpisodeServer = { serverName: string; items: EpisodeItem[] }
type FilmDetail = {
  name: string
  slug: string
  originalName?: string | null
  posterUrl?: string | null
  thumbUrl?: string | null
  year?: string | null
  quality?: string | null
  language?: string | null
  currentEpisode?: string | null
  avgRating?: number
  ratingCount?: number
  director?: string | null
  casts?: string | null
  description?: string | null
  inWatchlist?: boolean
  genres?: { slug: string; name: string }[]
  episodes?: EpisodeServer[]
}
type FilmDetailResponse = { success: boolean; data: FilmDetail }
type CommentItem = { id: string | number; username: string; body: string }
type CommentsResponse = { success: boolean; data: CommentItem[] }

const { t } = useI18n()
const route = useRoute()
const authStore = useAuthStore()
const slug = computed(() => String(route.params.slug || ''))

const { data, pending, refresh } = await useAsyncData(
  () => `film-${slug.value}`,
  () => $fetch<FilmDetailResponse>(`/api/public/films/${slug.value}`),
  { watch: [slug] }
)

const film = computed(() => data.value?.data || null)
const watchLink = computed(() => {
  const f = film.value
  if (!f) return '/'
  const server = f.episodes?.[0]
  const first = server?.items?.[0]
  if (!server || !first) return `/xem/${f.slug}`
  return `/xem/${f.slug}/${first.slug}?server=${encodeURIComponent(server.serverName)}`
})

const { data: commentsData, refresh: refreshComments } = await useAsyncData(
  () => `comments-${slug.value}`,
  () =>
    $fetch<CommentsResponse>(`/api/public/films/${slug.value}/comments`, {
      query: { page: 1, pageSize: 20 }
    }),
  { watch: [slug] }
)
const comments = computed(() => commentsData.value?.data || [])

const commentBody = ref('')
const commenting = ref(false)

async function toggleWatchlist() {
  try {
    if (film.value?.inWatchlist) {
      await useApiFetch(`/api/me/watchlist/${slug.value}`, { method: 'DELETE' })
      ElMessage.success(t('cineva.removedWatchlist'))
    } else {
      await useApiFetch(`/api/me/watchlist/${slug.value}`, { method: 'POST' })
      ElMessage.success(t('cineva.addedWatchlist'))
    }
    await refresh()
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || t('common.actionFailed'))
  }
}

async function submitComment() {
  if (!commentBody.value.trim()) return
  commenting.value = true
  try {
    await useApiFetch(`/api/public/films/${slug.value}/comments`, {
      method: 'POST',
      body: { body: commentBody.value.trim() }
    })
    commentBody.value = ''
    ElMessage.success(t('common.success'))
    await refreshComments()
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || t('common.actionFailed'))
  } finally {
    commenting.value = false
  }
}

useSeoMeta({
  title: () => (film.value ? `${film.value.name} — ${t('app.name')}` : t('app.name')),
  description: () => film.value?.originalName || t('app.tagline')
})
</script>
