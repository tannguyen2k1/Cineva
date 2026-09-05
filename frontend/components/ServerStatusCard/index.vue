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

const formatGiB = (gib: number = 0) => {
  const value = Number.isFinite(gib) ? gib : 0;
  const digits = value >= 100 ? 0 : value >= 10 ? 1 : 2;
  return `${value.toFixed(digits)} GB`;
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
      percentage: Math.min(100, Math.max(0, s.cpu || 0))
    },
    {
      key: 'ram',
      label: 'RAM',
      detail: `${formatGiB(s.ramUsed)} / ${formatGiB(s.ramTotal)}`,
      percentage: Math.min(100, Math.max(0, s.ram || 0))
    },
    {
      key: 'disk',
      label: 'Disk',
      detail: `${formatGiB(s.diskUsed)} / ${formatGiB(s.diskTotal)}`,
      percentage: Math.min(100, Math.max(0, s.disk || 0))
    }
  ];
});
</script>
