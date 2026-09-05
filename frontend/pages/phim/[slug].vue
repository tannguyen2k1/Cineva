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
        <div :class="styles.ratingRow">
          <div v-if="(film.ratingCount || 0) > 0" :class="styles.rating">
            ★ {{ film.avgRating }}
            <small>({{ film.ratingCount }})</small>
          </div>
          <div v-if="authStore.isLoggedIn" :class="styles.rateBox">
            <span>{{ t('cineva.yourRating') }}</span>
            <el-rate
              v-model="userScore"
              :max="10"
              :clearable="false"
              :colors="['#ffd66b', '#ffd66b', '#ffd66b']"
              void-color="rgba(255,255,255,0.2)"
              disabled-void-color="rgba(255,255,255,0.15)"
              @change="onRate"
            />
          </div>
          <NuxtLink v-else to="/login" :class="styles.rateHint">
            {{ t('cineva.loginToRate') }}
          </NuxtLink>
        </div>
        <div :class="styles.actions">
          <NuxtLink :to="watchLink" :class="styles.primaryBtn">{{ t('cineva.watchNow') }}</NuxtLink>
          <button
            v-if="authStore.isLoggedIn"
            type="button"
            :class="[styles.ghostBtn, film.isFollowing ? styles.ghostActive : '']"
            @click="toggleFollow"
          >
            {{ film.isFollowing ? t('cineva.unfollow') : t('cineva.follow') }}
          </button>
          <NuxtLink v-else to="/login" :class="styles.ghostBtn">
            {{ t('cineva.follow') }}
          </NuxtLink>
          <button
            v-if="authStore.isLoggedIn"
            type="button"
            :class="[styles.ghostBtn, film.inWatchlist ? styles.ghostActive : '']"
            @click="toggleWatchlist"
          >
            {{ film.inWatchlist ? t('cineva.removeWatchlist') : t('cineva.addWatchlist') }}
          </button>
          <NuxtLink v-else to="/login" :class="styles.ghostBtn">
            {{ t('cineva.addWatchlist') }}
          </NuxtLink>
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
      <div v-if="authStore.isLoggedIn && !replyTo" :class="styles.commentForm">
        <div :class="styles.composer">
          <el-input
            v-model="commentBody"
            type="textarea"
            :rows="3"
            :class="styles.commentInput"
            :placeholder="t('cineva.commentPlaceholder')"
            maxlength="2000"
            show-word-limit
          />
          <div :class="styles.composerTools">
            <EmojiPicker @pick="insertEmoji" />
          </div>
        </div>
        <div :class="styles.commentActions">
          <button
            type="button"
            :class="styles.commentSubmit"
            :disabled="commenting || !commentBody.trim()"
            @click="submitComment"
          >
            {{ commenting ? '...' : t('cineva.postComment') }}
          </button>
        </div>
      </div>
      <p v-else-if="!authStore.isLoggedIn" :class="styles.loginHint">
        <NuxtLink to="/login">{{ t('login.title') }}</NuxtLink> {{ t('cineva.toComment') }}
      </p>
      <div v-if="comments.length" :class="styles.commentList">
        <article v-for="c in comments" :key="c.id" :class="styles.commentItem">
          <UserProfile
            :username="c.username"
            :full-name="c.fullName"
            :avatar="c.avatar"
            :size="40"
            :show-name="false"
          />
          <div :class="styles.commentBody">
            <div :class="styles.commentMeta">
              <strong>{{ c.fullName || c.username }}</strong>
              <time v-if="c.createdAt">{{ formatDateTime(c.createdAt) }}</time>
            </div>
            <p>{{ c.body }}</p>
            <button
              v-if="authStore.isLoggedIn && replyParentId !== c.id"
              type="button"
              :class="styles.replyBtn"
              @click="startReply(c)"
            >
              {{ t('cineva.reply') }}
            </button>

            <div v-if="c.replies?.length" :class="styles.replies">
              <article
                v-for="r in c.replies"
                :key="r.id"
                :class="[styles.commentItem, styles.replyItem]"
              >
                <UserProfile
                  :username="r.username"
                  :full-name="r.fullName"
                  :avatar="r.avatar"
                  :size="32"
                  :show-name="false"
                />
                <div :class="styles.commentBody">
                  <div :class="styles.commentMeta">
                    <strong>{{ r.fullName || r.username }}</strong>
                    <time v-if="r.createdAt">{{ formatDateTime(r.createdAt) }}</time>
                  </div>
                  <p>{{ r.body }}</p>
                  <button
                    v-if="authStore.isLoggedIn && String(replyParentId) !== String(c.id)"
                    type="button"
                    :class="styles.replyBtn"
                    @click="startReply(c, r)"
                  >
                    {{ t('cineva.reply') }}
                  </button>
                </div>
              </article>
            </div>

            <div
              v-if="authStore.isLoggedIn && replyTo && String(replyParentId) === String(c.id)"
              :class="styles.inlineReply"
            >
              <p :class="styles.replyingTo">
                {{ t('cineva.replyingTo', { name: replyTo.fullName || replyTo.username }) }}
              </p>
              <div :class="styles.inlineComposer">
                <el-input
                  ref="replyInputRef"
                  v-model="commentBody"
                  type="textarea"
                  :rows="2"
                  :autosize="{ minRows: 1, maxRows: 3 }"
                  :class="styles.inlineInput"
                  :placeholder="t('cineva.replyPlaceholder', { name: replyTo.fullName || replyTo.username })"
                  maxlength="2000"
                  @keydown.ctrl.enter="submitComment"
                />
                <div :class="styles.inlineEmoji">
                  <EmojiPicker compact @pick="insertEmoji" />
                </div>
              </div>
              <div :class="styles.inlineActions">
                <button type="button" :class="styles.inlineCancel" @click="cancelReply">
                  {{ t('common.cancel') }}
                </button>
                <button
                  type="button"
                  :class="styles.inlineSubmit"
                  :disabled="commenting || !commentBody.trim()"
                  @click="submitComment"
                >
                  {{ commenting ? '...' : t('cineva.postReply') }}
                </button>
              </div>
            </div>
          </div>
        </article>
      </div>
      <el-empty v-else :description="t('cineva.noComments')" :image-size="64" />
    </section>
  </div>
  <el-empty v-else-if="!pending" :description="t('cineva.notFound')" />
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { useSiteUrl } from '~/composables/useSiteUrl'
import { seoPlainText } from '~/utils/seo'
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
  totalEpisodes?: string | number | null
  avgRating?: number
  ratingCount?: number
  userScore?: number | null
  director?: string | null
  casts?: string | null
  description?: string | null
  inWatchlist?: boolean
  isFollowing?: boolean
  genres?: { slug: string; name: string }[]
  episodes?: EpisodeServer[]
}
type FilmDetailResponse = { success: boolean; data: FilmDetail }
type CommentItem = {
  id: string | number
  username: string
  fullName?: string | null
  avatar?: string | null
  body: string
  createdAt?: string
  parentId?: string | null
  replies?: CommentItem[]
}
type CommentsResponse = { success: boolean; data: CommentItem[] }

const { t } = useI18n()
const { formatDateTime } = useDateTime()
const { absoluteUrl } = useSiteUrl()
const route = useRoute()
const authStore = useAuthStore()
const slug = computed(() => String(route.params.slug || ''))
const requestFetch = useRequestFetch()

const { data, pending, refresh } = await useAsyncData(
  () => `film-${slug.value}`,
  () => requestFetch<FilmDetailResponse>(`/api/public/films/${slug.value}`),
  { watch: [slug] }
)

const film = computed(() => data.value?.data || null)
const userScore = ref(0)

watch(
  film,
  (f) => {
    userScore.value = f?.userScore || 0
  },
  { immediate: true }
)

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
const replyTo = ref<CommentItem | null>(null)
const replyParentId = ref<string | number | null>(null)
const replyInputRef = ref<{ focus?: () => void } | null>(null)

async function startReply(root: CommentItem, mention?: CommentItem) {
  replyParentId.value = root.id
  replyTo.value = mention || root
  commentBody.value = ''
  await nextTick()
  replyInputRef.value?.focus?.()
}

function cancelReply() {
  replyTo.value = null
  replyParentId.value = null
  commentBody.value = ''
}

function insertEmoji(emoji: string) {
  commentBody.value = `${commentBody.value}${emoji}`
}

async function toggleFollow() {
  try {
    if (film.value?.isFollowing) {
      await useApiFetch(`/api/me/follows/${slug.value}`, { method: 'DELETE' })
      ElMessage.success(t('cineva.unfollowed'))
    } else {
      await useApiFetch(`/api/me/follows/${slug.value}`, { method: 'POST' })
      ElMessage.success(t('cineva.followed'))
    }
    await refresh()
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || t('common.actionFailed'))
  }
}

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

async function onRate(score: number) {
  const value = Math.round(Number(score))
  if (value < 1 || value > 10) return
  try {
    const res = await useApiFetch(`/api/me/ratings/${slug.value}`, {
      method: 'PUT',
      body: { score: value }
    })
    const payload = res?.data
    if (data.value?.data && payload) {
      data.value.data.avgRating = payload.avgRating
      data.value.data.ratingCount = payload.ratingCount
      data.value.data.userScore = payload.score
    }
    userScore.value = value
    ElMessage.success(t('cineva.ratedOk'))
  } catch (err: any) {
    userScore.value = film.value?.userScore || 0
    ElMessage.error(err?.data?.statusMessage || t('common.actionFailed'))
  }
}

async function submitComment() {
  if (!commentBody.value.trim()) return
  commenting.value = true
  try {
    await useApiFetch(`/api/public/films/${slug.value}/comments`, {
      method: 'POST',
      body: {
        body: commentBody.value.trim(),
        ...(replyParentId.value ? { parentId: String(replyParentId.value) } : {})
      }
    })
    commentBody.value = ''
    cancelReply()
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
  description: () =>
    seoPlainText(film.value?.description) ||
    film.value?.originalName ||
    t('cineva.seoHome'),
  ogTitle: () => (film.value ? `${film.value.name} — ${t('app.name')}` : t('app.name')),
  ogDescription: () =>
    seoPlainText(film.value?.description) ||
    film.value?.originalName ||
    t('cineva.seoHome'),
  ogType: 'video.movie',
  ogUrl: () => absoluteUrl(`/phim/${slug.value}`),
  ogImage: () =>
    film.value?.posterUrl || film.value?.thumbUrl || absoluteUrl('/brand/cineva-logo.png'),
  twitterCard: 'summary_large_image',
  robots: 'index, follow'
})

const filmJsonLd = computed(() => {
  const f = film.value
  if (!f) return null
  const canonical = absoluteUrl(`/phim/${slug.value}`)
  return {
    '@context': 'https://schema.org',
    '@type': f.totalEpisodes && Number(f.totalEpisodes) > 1 ? 'TVSeries' : 'Movie',
    name: f.name,
    alternateName: f.originalName || undefined,
    description: seoPlainText(f.description, 300) || undefined,
    image: f.posterUrl || f.thumbUrl || undefined,
    dateCreated: f.year || undefined,
    genre: (f.genres || []).map((g) => g.name),
    aggregateRating:
      f.ratingCount && f.avgRating
        ? {
            '@type': 'AggregateRating',
            ratingValue: f.avgRating,
            ratingCount: f.ratingCount,
            bestRating: 10
          }
        : undefined,
    url: canonical
  }
})

useHead(() => ({
  link: [{ rel: 'canonical', href: absoluteUrl(`/phim/${slug.value}`) }],
  script: filmJsonLd.value
    ? [
        {
          type: 'application/ld+json',
          innerHTML: JSON.stringify(filmJsonLd.value)
        }
      ]
    : []
}))
</script>
