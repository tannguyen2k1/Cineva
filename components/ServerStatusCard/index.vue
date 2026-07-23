<template>
  <el-card :class="[styles.card]" shadow="never">
    <template #header>
      <div :class="styles.header">
        <span>{{ t('dashboard.serverStatus') }}</span>
        <span :class="[styles.liveBadge, connected ? styles.liveOn : styles.liveOff]">
          {{ connected ? 'LIVE' : 'OFF' }}
        </span>
      </div>
    </template>

    <el-skeleton v-if="loading" animated :rows="4" />
    <div v-else>
      <div
        v-for="(metric, index) in metrics"
        :key="metric.key"
        :class="[styles.statusItem, index > 0 ? styles.spaced : '']"
      >
        <div :class="styles.statusInfo">
          <span>{{ metric.label }}</span>
          <span>{{ metric.detail }}</span>
        </div>
        <el-progress
          :percentage="metric.percentage"
          :status="getUsageStatus(metric.percentage)"
        />
      </div>
    </div>
  </el-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import styles from './ServerStatusCard.module.scss';

export interface ServerStats {
  cpu?: number;
  cpuCores?: number;
  ram?: number;
  ramUsed?: number;
  ramTotal?: number;
  disk?: number;
  diskUsed?: number;
  diskTotal?: number;
}

const props = withDefaults(defineProps<{
  loading?: boolean;
  connected?: boolean;
  server?: ServerStats | null;
}>(), {
  loading: false,
  connected: false,
  server: null
});

const { t } = useI18n();

const formatBytes = (bytes: number = 0) => {
  if (!bytes || bytes < 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / Math.pow(1024, i);
  const digits = value >= 100 || i === 0 ? 0 : value >= 10 ? 1 : 2;
  return `${value.toFixed(digits)} ${units[i]}`;
};

const getUsageStatus = (percentage: number = 0) => {
  if (percentage >= 90) return 'exception';
  if (percentage >= 75) return 'warning';
  return 'success';
};

const metrics = computed(() => {
  const s = props.server || {};
  return [
    {
      key: 'cpu',
      label: 'CPU',
      detail: `${s.cpu || 0}% · ${s.cpuCores || 0} ${t('dashboard.cores')}`,
      percentage: s.cpu || 0
    },
    {
      key: 'ram',
      label: 'RAM',
      detail: `${formatBytes(s.ramUsed)} / ${formatBytes(s.ramTotal)}`,
      percentage: s.ram || 0
    },
    {
      key: 'disk',
      label: 'Disk',
      detail: `${formatBytes(s.diskUsed)} / ${formatBytes(s.diskTotal)}`,
      percentage: s.disk || 0
    }
  ];
});
</script>
