<template>
  <div :class="styles.dashboardPage">
    <el-row :gutter="16" :class="styles.statCards">
      <el-col v-for="card in statCards" :key="card.key" :span="8" :xs="12" :sm="12" :md="8" :lg="8" :xl="8">
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
            <span>{{ t('dashboard.recentActivity') }}</span>
          </div>
        </template>
        <el-skeleton v-if="pending" animated :rows="4" />
        <div v-else-if="statsData?.recentLogs?.length" :class="styles.timelineScroll">
          <el-timeline>
            <el-timeline-item
              v-for="log in statsData.recentLogs"
              :key="log.id"
              :timestamp="formatDateTime(log.createdAt)"
              placement="top"
              :type="log.type"
            >
              <el-card shadow="hover">
                <h4>{{ log.action }}</h4>
                <p>{{ log.details }}</p>
              </el-card>
            </el-timeline-item>
          </el-timeline>
        </div>
        <el-empty v-else :description="t('dashboard.noActivity')" :image-size="72" />
      </el-card>

      <div :class="styles.sideCol">
        <ServerStatusCard
          :loading="pending"
          :connected="wsConnected"
          :server="statsData?.server"
        />

        <el-card :class="[styles.premiumCard, styles.membersCard]" shadow="never">
          <template #header>
            <div :class="styles.cardHeader">
              <span>{{ t('dashboard.recentUsers') }}</span>
            </div>
          </template>
          <el-skeleton v-if="pending" animated :rows="3" />
          <div v-else-if="statsData?.recentUsers?.length">
            <div
              v-for="(u, index) in statsData.recentUsers"
              :key="u.id"
              :class="[styles.memberRow, Number(index) > 0 ? styles.mt3 : '']"
            >
              <UserProfile
                :username="u.username"
                :full-name="u.fullName"
                :avatar="u.avatar"
                size="default"
                :gap="12"
              />
              <span :class="styles.memberDate">
                {{ formatDate(u.createdAt) }}
              </span>
            </div>
          </div>
          <el-empty v-else :description="t('dashboard.noActivity')" :image-size="60" />
        </el-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { User, Film, ChatDotRound, Refresh } from '@element-plus/icons-vue';
import styles from './dashboard.module.scss';
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import type { Component } from 'vue';
import { useDateTime } from '~/composables/useDateTime';

const { t } = useI18n();
const { formatDate, formatDateTime } = useDateTime();
const statsData = ref<any>(null);
const pending = ref(false);

type IconTone = 'Blue' | 'Green' | 'Amber' | 'Red';
type TrendTone = 'Success' | 'Warning' | 'Danger';

const lastSyncText = computed(() => {
  const sync = statsData.value?.lastSync;
  if (!sync?.startedAt) return t('dashboard.noSyncYet');
  const status = sync.status === 'success' ? t('sync.statusSuccess') : sync.status;
  return `${formatDateTime(sync.startedAt)} · ${status}`;
});

const statCards = computed(() => {
  const stats = statsData.value?.stats;
  return [
    {
      key: 'films',
      title: t('dashboard.films'),
      value: stats?.films || 0,
      icon: Film,
      iconTone: 'Amber' as IconTone,
      trendText: lastSyncText.value,
      trendTone: 'Success' as TrendTone,
      trendIcon: Refresh as Component
    },
    {
      key: 'comments',
      title: t('dashboard.comments'),
      value: stats?.comments || 0,
      icon: ChatDotRound,
      iconTone: 'Green' as IconTone,
      trendText: t('dashboard.noChange'),
      trendTone: 'Success' as TrendTone,
      trendIcon: Refresh as Component
    },
    {
      key: 'users',
      title: t('dashboard.users'),
      value: stats?.users || 0,
      icon: User,
      iconTone: 'Blue' as IconTone,
      trendText: t('dashboard.noChange'),
      trendTone: 'Warning' as TrendTone,
      trendIcon: Refresh as Component
    }
  ];
});

let ws: WebSocket | null = null;
const wsConnected = ref(false);

function onWsMessage(event: MessageEvent) {
  try {
    const payload = JSON.parse(typeof event.data === 'string' ? event.data : '');
    if (payload?.type !== 'server-stats' || !payload.data) return;
    if (!statsData.value) {
      statsData.value = { server: payload.data };
      return;
    }
    statsData.value.server = payload.data;
  } catch (err) {
    console.error('WS server-stats parse error:', err);
  }
}

async function connectWs() {
  if (!import.meta.client) return;
  try {
    const { ticket } = await useApiFetch('/api/auth/ws-ticket');
    const config = useRuntimeConfig();
    const base = String(config.public.wsBase || 'ws://127.0.0.1:8000').replace(/\/$/, '');
    const url = `${base}/ws/server-stats?token=${ticket}`;

    ws = new WebSocket(url);
    ws.onopen = () => { wsConnected.value = true; };
    ws.onmessage = onWsMessage;
    ws.onclose = () => { wsConnected.value = false; };
    ws.onerror = () => { wsConnected.value = false; };
  } catch {
    console.error('Failed to get WS ticket');
  }
}

function closeWs() {
  if (ws) {
    ws.close();
    ws = null;
    wsConnected.value = false;
  }
}

const fetchStats = async () => {
  pending.value = true;
  try {
    const res = await useApiFetch('/api/dashboard/stats');
    if (res.success) {
      statsData.value = res.data;
    }
  } catch (err) {
    console.error('Lỗi khi lấy dữ liệu dashboard:', err);
  } finally {
    pending.value = false;
  }
};

onMounted(async () => {
  await fetchStats();
  connectWs();
});

usePageRefresh(() => fetchStats());

onBeforeUnmount(() => {
  closeWs();
});
</script>
