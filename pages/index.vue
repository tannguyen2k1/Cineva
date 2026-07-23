<template>
  <div :class="styles.dashboardPage">
    <el-row :gutter="16" :class="styles.statCards">
      <el-col :span="6">
        <el-card :class="[styles.premiumCard, styles.statCard]" shadow="never">
          <div :class="styles.statHeader">
            <span class="title">Người dùng</span>
            <el-icon :class="[styles.icon, styles.userIcon]"><User /></el-icon>
          </div>
          <div :class="styles.statValue">
            <el-skeleton v-if="pending" animated :rows="1" />
            <span v-else>{{ statsData?.stats.users || 0 }}</span>
          </div>
          <div :class="[styles.statFooter, styles.textSuccess]">
            <el-icon><TopRight /></el-icon>
            <span>+12% so với tháng trước</span>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card :class="[styles.premiumCard, styles.statCard]" shadow="never">
          <div :class="styles.statHeader">
            <span class="title">Vai trò (Roles)</span>
            <el-icon :class="[styles.icon, styles.revenueIcon]"><Key /></el-icon>
          </div>
          <div :class="styles.statValue">
            <el-skeleton v-if="pending" animated :rows="1" />
            <span v-else>{{ statsData?.stats.roles || 0 }}</span>
          </div>
          <div :class="[styles.statFooter, styles.textSuccess]">
            <el-icon><TopRight /></el-icon>
            <span>+8% so với tháng trước</span>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card :class="[styles.premiumCard, styles.statCard]" shadow="never">
          <div :class="styles.statHeader">
            <span class="title">Tenants</span>
            <el-icon :class="[styles.icon, styles.tenantIcon]"><House /></el-icon>
          </div>
          <div :class="styles.statValue">
            <el-skeleton v-if="pending" animated :rows="1" />
            <span v-else>{{ statsData?.stats.tenants || 0 }}</span>
          </div>
          <div :class="[styles.statFooter, styles.textWarning]">
            <el-icon><Right /></el-icon>
            <span>Không thay đổi</span>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card :class="[styles.premiumCard, styles.statCard]" shadow="never">
          <div :class="styles.statHeader">
            <span class="title">Nhật ký (Logs)</span>
            <el-icon :class="[styles.icon, styles.errorIcon]"><Document /></el-icon>
          </div>
          <div :class="styles.statValue">
            <el-skeleton v-if="pending" animated :rows="1" />
            <span v-else>{{ statsData?.stats.logs || 0 }}</span>
          </div>
          <div :class="[styles.statFooter, styles.textDanger]">
            <el-icon><BottomRight /></el-icon>
            <span>-2% so với tuần trước</span>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <div :class="styles.mainGrid">
      <el-card :class="[styles.premiumCard, styles.fillCard]" shadow="never">
        <template #header>
          <div :class="styles.cardHeader">
            <span>Hoạt động gần đây</span>
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
        <el-empty v-else description="Chưa có hoạt động nào" :image-size="72" />
      </el-card>

      <div :class="styles.sideCol">
        <el-card :class="[styles.premiumCard, styles.sideCard]" shadow="never">
          <template #header>
            <div :class="styles.cardHeader">
              <span>Trạng thái máy chủ</span>
              <span :class="[styles.liveBadge, wsConnected ? styles.liveOn : styles.liveOff]">
                {{ wsConnected ? 'LIVE' : 'OFF' }}
              </span>
            </div>
          </template>
          <el-skeleton v-if="pending" animated :rows="4" />
          <div v-else>
            <div :class="styles.statusItem">
              <div :class="styles.statusInfo">
                <span>CPU</span>
                <span>{{ statsData?.server.cpu }}% · {{ statsData?.server.cpuCores || 0 }} nhân</span>
              </div>
              <el-progress
                :percentage="statsData?.server.cpu || 0"
                :status="getUsageStatus(statsData?.server.cpu)"
              />
            </div>
            <div :class="[styles.statusItem, styles.mt3]">
              <div :class="styles.statusInfo">
                <span>RAM</span>
                <span>
                  {{ formatBytes(statsData?.server.ramUsed) }} / {{ formatBytes(statsData?.server.ramTotal) }}
                </span>
              </div>
              <el-progress
                :percentage="statsData?.server.ram || 0"
                :status="getUsageStatus(statsData?.server.ram)"
              />
            </div>
            <div :class="[styles.statusItem, styles.mt3]">
              <div :class="styles.statusInfo">
                <span>Disk</span>
                <span>
                  {{ formatBytes(statsData?.server.diskUsed) }} / {{ formatBytes(statsData?.server.diskTotal) }}
                </span>
              </div>
              <el-progress
                :percentage="statsData?.server.disk || 0"
                :status="getUsageStatus(statsData?.server.disk)"
              />
            </div>
          </div>
        </el-card>

        <el-card :class="[styles.premiumCard, styles.membersCard]" shadow="never">
          <template #header>
            <div :class="styles.cardHeader">
              <span>Thành viên mới</span>
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
                {{ new Date(u.createdAt).toLocaleDateString('vi-VN') }}
              </span>
            </div>
          </div>
          <el-empty v-else description="Chưa có thành viên" :image-size="60" />
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

const authStore = useAuthStore();
const statsData = ref<any>(null);
const pending = ref(false);

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

const formatBytes = (bytes: number = 0) => {
  if (!bytes || bytes < 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / Math.pow(1024, i);
  const digits = value >= 100 || i === 0 ? 0 : value >= 10 ? 1 : 2;
  return `${value.toFixed(digits)} ${units[i]}`;
};

const formatDate = (dateString: string) => {
  const date = new Date(dateString);
  return date.toLocaleString('vi-VN');
};

const getUsageStatus = (percentage: number = 0) => {
  if (percentage >= 90) return 'exception';
  if (percentage >= 75) return 'warning';
  return 'success';
};

onMounted(async () => {
  await fetchStats();
  openWs();
});

onBeforeUnmount(() => {
  closeWs();
});
</script>
