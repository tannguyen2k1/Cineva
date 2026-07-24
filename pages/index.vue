<template>
  <div :class="styles.dashboardPage">
    <el-row :gutter="16" :class="styles.statCards">
      <el-col v-for="card in statCards" :key="card.key" :span="6" :xs="12" :sm="12" :md="12" :lg="6" :xl="6">
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
              :timestamp="formatDate(log.createdAt)"
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
                {{ new Date(u.createdAt).toLocaleDateString(dateLocale) }}
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
import { User, TopRight, Key, House, Right, Document, BottomRight } from '@element-plus/icons-vue';
import styles from './dashboard.module.scss';
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useWebSocket } from '@vueuse/core';
import { useAuthStore } from '~/stores/auth';
import type { Component } from 'vue';

const { t, locale } = useI18n();
const authStore = useAuthStore();
const statsData = ref<any>(null);
const pending = ref(false);
const dateLocale = computed(() => (locale.value === 'en' ? 'en-US' : 'vi-VN'));

type IconTone = 'Blue' | 'Green' | 'Amber' | 'Red';
type TrendTone = 'Success' | 'Warning' | 'Danger';

const statCards = computed(() => {
  const stats = statsData.value?.stats;
  return [
    {
      key: 'users',
      title: t('dashboard.users'),
      value: stats?.users || 0,
      icon: User,
      iconTone: 'Blue' as IconTone,
      trendText: `+12% ${t('dashboard.vsLastMonth')}`,
      trendTone: 'Success' as TrendTone,
      trendIcon: TopRight as Component
    },
    {
      key: 'roles',
      title: t('dashboard.roles'),
      value: stats?.roles || 0,
      icon: Key,
      iconTone: 'Green' as IconTone,
      trendText: `+8% ${t('dashboard.vsLastMonth')}`,
      trendTone: 'Success' as TrendTone,
      trendIcon: TopRight as Component
    },
    {
      key: 'tenants',
      title: t('dashboard.tenants'),
      value: stats?.tenants || 0,
      icon: House,
      iconTone: 'Amber' as IconTone,
      trendText: t('dashboard.noChange'),
      trendTone: 'Warning' as TrendTone,
      trendIcon: Right as Component
    },
    {
      key: 'logs',
      title: t('dashboard.logs'),
      value: stats?.logs || 0,
      icon: Document,
      iconTone: 'Red' as IconTone,
      trendText: `-2% ${t('dashboard.vsLastWeek')}`,
      trendTone: 'Danger' as TrendTone,
      trendIcon: BottomRight as Component
    }
  ];
});

const wsUrl = computed(() => {
  if (!import.meta.client) return undefined;
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  return `${protocol}//${window.location.host}/ws/server-stats`;
});

const { status: wsStatus, open: openWs, close: closeWs } = useWebSocket(wsUrl, {
  immediate: false,
  autoReconnect: {
    retries: 10,
    delay: 2000
  },
  onMessage(_ws, event) {
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
});

const wsConnected = computed(() => wsStatus.value === 'OPEN');

const fetchStats = async () => {
  pending.value = true;
  try {
    const headers: any = {};
    if (authStore.token) headers.Authorization = `Bearer ${authStore.token}`;
    if (authStore.tenant_id) headers['x-tenant-id'] = authStore.tenant_id;

    const res = await $fetch<any>('/api/dashboard/stats', { headers });
    if (res.success) {
      statsData.value = res.data;
    }
  } catch (err) {
    console.error('Lỗi khi lấy dữ liệu dashboard:', err);
  } finally {
    pending.value = false;
  }
};

const formatDate = (dateString: string) => {
  const date = new Date(dateString);
  return date.toLocaleString(locale.value === 'en' ? 'en-US' : 'vi-VN');
};

onMounted(async () => {
  await fetchStats();
  openWs();
});

onBeforeUnmount(() => {
  closeWs();
});
</script>
