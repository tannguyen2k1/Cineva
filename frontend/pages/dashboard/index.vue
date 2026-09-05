<template>
  <div :class="styles.dashboardPage">
    <el-row :gutter="16" :class="styles.statCards">
      <el-col v-for="card in statCards" :key="card.key" :span="6" :xs="12" :sm="12" :md="6" :lg="6" :xl="6">
        <StatCard
          :title="card.title"
          :value="card.value"
          :loading="pending"
          :icon="card.icon"
          :icon-tone="card.iconTone"
          :trend-text="card.trendText"
          :trend-tone="card.trendTone"
          :trend-icon="card.trendIcon"
        />
      </el-col>
    </el-row>

    <div :class="styles.mainGrid">
      <el-card :class="[styles.premiumCard, styles.fillCard]" shadow="never">
        <template #header>
          <div :class="styles.cardHeader">
            <span>{{ t('dashboard.overviewTitle') }}</span>
            <el-button type="primary" link @click="navigateTo('/films/sync')">
              {{ t('dashboard.openSync') }}
            </el-button>
          </div>
        </template>

        <el-skeleton v-if="pending" animated :rows="6" />
        <div v-else :class="styles.overviewBody">
          <section :class="styles.syncBlock">
            <div :class="styles.syncHead">
              <strong>{{ t('dashboard.lastSync') }}</strong>
              <el-tag :type="syncTagType" size="small" effect="light">
                {{ syncStatusLabel }}
              </el-tag>
            </div>
            <p :class="styles.syncMeta">
              <template v-if="statsData?.lastSync">
                {{ syncJobLabel }} · {{ t('sync.itemsUpserted') }}:
                {{ statsData.lastSync.itemsUpserted ?? 0 }}
                <span v-if="statsData.lastSync.startedAt">
                  · {{ formatDateTime(statsData.lastSync.startedAt) }}
                </span>
              </template>
              <template v-else>{{ t('dashboard.noSyncYet') }}</template>
            </p>
            <p v-if="statsData?.lastSync?.error" :class="styles.syncError">
              {{ statsData.lastSync.error }}
            </p>
          </section>

          <div :class="styles.reportList">
            <button
              v-for="row in reportRows"
              :key="row.key"
              type="button"
              :class="styles.reportRow"
              @click="navigateTo(row.to)"
            >
              <div :class="styles.reportLabel">
                <el-icon><component :is="row.icon" /></el-icon>
                <div>
                  <strong>{{ row.title }}</strong>
                  <span>{{ row.subtitle }}</span>
                </div>
              </div>
              <div :class="styles.reportValue">
                <b>{{ row.value }}</b>
                <el-icon><ArrowRight /></el-icon>
              </div>
            </button>
          </div>
        </div>
      </el-card>

      <div :class="styles.sideCol">
        <ServerStatusCard
          :loading="pending"
          :connected="wsConnected"
          :server="statsData?.server"
        />
        <TrafficChart :loading="pending" :series="statsData?.traffic || []" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  User,
  Film,
  ChatDotRound,
  Picture,
  Star,
  Hide,
  ArrowRight,
  Refresh
} from '@element-plus/icons-vue'
import styles from './dashboard.module.scss'
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import type { Component } from 'vue'
import { useDateTime } from '~/composables/useDateTime'

const { t } = useI18n()
const { formatDateTime } = useDateTime()
const statsData = ref<any>(null)
const pending = ref(false)

type IconTone = 'Blue' | 'Green' | 'Amber' | 'Red'
type TrendTone = 'Success' | 'Warning' | 'Danger'

const stats = computed(() => statsData.value?.stats || {})

const syncStatusLabel = computed(() => {
  const status = statsData.value?.lastSync?.status
  if (!status) return t('dashboard.noSyncYet')
  if (status === 'success') return t('sync.statusSuccess')
  if (status === 'failed') return t('sync.statusFailed')
  if (status === 'running') return t('sync.statusRunning')
  return status
})

const syncTagType = computed(() => {
  const status = statsData.value?.lastSync?.status
  if (status === 'success') return 'success'
  if (status === 'failed') return 'danger'
  if (status === 'running') return 'warning'
  return 'info'
})

const syncJobLabel = computed(() => {
  const job = statsData.value?.lastSync?.jobType
  if (job === 'catalog') return t('sync.jobCatalog')
  if (job === 'incremental') return t('sync.jobIncremental')
  return job || '—'
})

const statCards = computed(() => {
  const s = stats.value
  return [
    {
      key: 'films',
      title: t('dashboard.films'),
      value: s.films || 0,
      icon: Film,
      iconTone: 'Amber' as IconTone,
      trendText: t('dashboard.filmsVisibleHint', { count: s.filmsVisible || 0 }),
      trendTone: 'Success' as TrendTone,
      trendIcon: Film as Component
    },
    {
      key: 'comments',
      title: t('dashboard.comments'),
      value: s.comments || 0,
      icon: ChatDotRound,
      iconTone: 'Green' as IconTone,
      trendText: t('dashboard.commentsHiddenHint', { count: s.commentsHidden || 0 }),
      trendTone: (s.commentsHidden ? 'Warning' : 'Success') as TrendTone,
      trendIcon: ChatDotRound as Component
    },
    {
      key: 'users',
      title: t('dashboard.users'),
      value: s.users || 0,
      icon: User,
      iconTone: 'Blue' as IconTone,
      trendText: t('dashboard.membersHint'),
      trendTone: 'Success' as TrendTone,
      trendIcon: User as Component
    },
    {
      key: 'cms',
      title: t('dashboard.cms'),
      value: `${s.bannersActive || 0}/${s.featured || 0}`,
      icon: Picture,
      iconTone: 'Red' as IconTone,
      trendText: t('dashboard.cmsHint'),
      trendTone: 'Warning' as TrendTone,
      trendIcon: Star as Component
    }
  ]
})

const reportRows = computed(() => {
  const s = stats.value
  return [
    {
      key: 'films',
      title: t('dashboard.reportFilms'),
      subtitle: t('dashboard.reportFilmsSub', {
        visible: s.filmsVisible || 0,
        hidden: s.filmsHidden || 0
      }),
      value: s.films || 0,
      to: '/films',
      icon: Film
    },
    {
      key: 'hidden',
      title: t('dashboard.reportHidden'),
      subtitle: t('dashboard.reportHiddenSub'),
      value: s.filmsHidden || 0,
      to: '/films',
      icon: Hide
    },
    {
      key: 'comments',
      title: t('dashboard.reportComments'),
      subtitle: t('dashboard.reportCommentsSub', { hidden: s.commentsHidden || 0 }),
      value: s.comments || 0,
      to: '/films/comments',
      icon: ChatDotRound
    },
    {
      key: 'banners',
      title: t('dashboard.reportBanners'),
      subtitle: t('dashboard.reportBannersSub', { active: s.bannersActive || 0 }),
      value: s.banners || 0,
      to: '/films/banners',
      icon: Picture
    },
    {
      key: 'featured',
      title: t('dashboard.reportFeatured'),
      subtitle: t('dashboard.reportFeaturedSub'),
      value: s.featured || 0,
      to: '/films/featured',
      icon: Star
    },
    {
      key: 'sync',
      title: t('dashboard.reportSync'),
      subtitle: syncStatusLabel.value,
      value: statsData.value?.lastSync?.itemsUpserted ?? '—',
      to: '/films/sync',
      icon: Refresh
    }
  ]
})

let ws: WebSocket | null = null
const wsConnected = ref(false)

function onWsMessage(event: MessageEvent) {
  try {
    const payload = JSON.parse(typeof event.data === 'string' ? event.data : '')
    if (payload?.type !== 'server-stats' || !payload.data) return
    if (!statsData.value) {
      statsData.value = { server: payload.data }
      return
    }
    statsData.value.server = payload.data
  } catch (err) {
    console.error('WS server-stats parse error:', err)
  }
}

async function connectWs() {
  if (!import.meta.client) return
  try {
    const { ticket } = await useApiFetch('/api/auth/ws-ticket')
    const config = useRuntimeConfig()
    const base = String(config.public.wsBase || 'ws://127.0.0.1:8000').replace(/\/$/, '')
    const url = `${base}/ws/server-stats?token=${ticket}`

    ws = new WebSocket(url)
    ws.onopen = () => { wsConnected.value = true }
    ws.onmessage = onWsMessage
    ws.onclose = () => { wsConnected.value = false }
    ws.onerror = () => { wsConnected.value = false }
  } catch {
    console.error('Failed to get WS ticket')
  }
}

function closeWs() {
  if (ws) {
    ws.close()
    ws = null
    wsConnected.value = false
  }
}

const fetchStats = async () => {
  pending.value = true
  try {
    const res = await useApiFetch('/api/dashboard/stats')
    if (res.success) {
      statsData.value = res.data
    }
  } catch (err) {
    console.error('Lỗi khi lấy dữ liệu dashboard:', err)
  } finally {
    pending.value = false
  }
}

onMounted(async () => {
  await fetchStats()
  connectWs()
})

usePageRefresh(() => fetchStats())

onBeforeUnmount(() => {
  closeWs()
})
</script>
