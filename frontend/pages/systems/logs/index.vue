<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="error.message || error" show-icon :class="styles.alert" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <el-input
          v-model="searchQuery"
          :placeholder="t('common.search')"
          :prefix-icon="Search"
          :class="styles.searchInput"
          clearable
        />

        <el-select
          v-model="activeCategory"
          :placeholder="t('logs.category')"
          :class="styles.filterSelect"
          clearable
        >
          <el-option :label="t('logs.categoryAll')" value="all" />
          <el-option :label="t('logs.categoryWatch')" value="watch" />
          <el-option :label="t('logs.categoryEngagement')" value="engagement" />
          <el-option :label="t('logs.categoryAuth')" value="auth" />
          <el-option :label="t('logs.categorySystem')" value="system" />
        </el-select>

        <el-select
          v-model="actionFilter"
          :placeholder="t('logs.action')"
          :class="styles.filterSelect"
          clearable
        >
          <el-option :label="t('logs.all')" value="" />
          <el-option
            v-for="act in actionOptions"
            :key="act.value"
            :label="act.label"
            :value="act.value"
          />
        </el-select>

        <div :class="styles.dateRangeWrap">
          <el-date-picker
            v-model="dateRange"
            type="daterange"
            :range-separator="t('logs.to')"
            :start-placeholder="t('logs.startDate')"
            :end-placeholder="t('logs.endDate')"
            value-format="YYYY-MM-DD"
            clearable
          />
        </div>

        <el-tag
          v-if="selectedUserId"
          type="info"
          closable
          :class="styles.userFilterTag"
          @close="clearUserFilter"
        >
          {{ selectedUserLabel || selectedUserId }}
        </el-tag>
      </div>

      <ClientOnly>
        <div :class="styles.contentArea">
          <!-- Desktop Table -->
          <DataTable
            v-if="!appStore.isMobile"
            :data="apiResponse?.data || []"
            :total="apiResponse?.total || 0"
            :loading="pending"
            v-model:page-size="pageSize"
            v-model:current-page="currentPage"
            row-key="id"
            @row-click="openInspect"
          >
            <!-- Time -->
            <el-table-column prop="createdAt" :label="t('logs.time')" width="170">
              <template #default="scope">
                <el-tooltip :content="formatDateTime(scope.row.createdAt)" placement="top">
                  <div :class="styles.timeCol">
                    <span :class="styles.relTime">{{ formatRelativeTime(scope.row.createdAt) }}</span>
                    <span :class="styles.absTime">{{ formatDateTime(scope.row.createdAt).split(' ')[1] }}</span>
                  </div>
                </el-tooltip>
              </template>
            </el-table-column>

            <!-- Actor -->
            <el-table-column prop="actor" :label="t('logs.actor')" min-width="180">
              <template #default="scope">
                <div
                  :class="styles.actorCell"
                  :title="t('logs.filterByUser')"
                  @click.stop="filterByUser(scope.row)"
                >
                  <el-avatar
                    :size="30"
                    :src="scope.row.actorAvatar || undefined"
                    :class="styles.actorAvatar"
                  >
                    {{ (scope.row.actor || scope.row.actorUsername || 'S').slice(0, 1).toUpperCase() }}
                  </el-avatar>
                  <div :class="styles.actorMeta">
                    <span :class="styles.actorName">{{ scope.row.actor || scope.row.actorUsername || t('logs.system') }}</span>
                    <span v-if="scope.row.actorUsername" :class="styles.actorUsername">@{{ scope.row.actorUsername }}</span>
                  </div>
                </div>
              </template>
            </el-table-column>

            <!-- Action -->
            <el-table-column prop="action" :label="t('logs.action')" width="170">
              <template #default="scope">
                <el-tag :type="getActionType(scope.row.action)" size="small" :class="styles.actionTag">
                  <el-icon><component :is="getActionIcon(scope.row.action)" /></el-icon>
                  {{ formatActionName(scope.row.action) }}
                </el-tag>
              </template>
            </el-table-column>

            <!-- Summary / Content -->
            <el-table-column :label="t('logs.details')" min-width="320">
              <template #default="scope">
                <!-- Film Watch -->
                <div v-if="scope.row.action === 'WATCH_FILM'" :class="styles.summaryCell">
                  <img
                    v-if="scope.row.details?.posterUrl"
                    :src="scope.row.details.posterUrl"
                    :alt="scope.row.details.filmName"
                    :class="styles.filmThumb"
                    loading="lazy"
                  />
                  <div :class="styles.filmMeta">
                    <span :class="styles.filmTitle">{{ scope.row.details?.filmName || '-' }}</span>
                    <div :class="styles.filmSub">
                      <el-tag size="small" effect="plain" type="info">{{ scope.row.details?.episodeName || t('logs.episode') }}</el-tag>
                      <span v-if="scope.row.details?.positionSec">{{ formatDuration(scope.row.details.positionSec) }}</span>
                    </div>
                  </div>
                </div>

                <!-- Film Watchlist / Follow -->
                <div v-else-if="scope.row.action === 'ADD_WATCHLIST' || scope.row.action === 'FOLLOW_FILM'" :class="styles.summaryCell">
                  <img
                    v-if="scope.row.details?.posterUrl"
                    :src="scope.row.details.posterUrl"
                    :alt="scope.row.details.filmName"
                    :class="styles.filmThumb"
                    loading="lazy"
                  />
                  <div :class="styles.filmMeta">
                    <span :class="styles.filmTitle">{{ scope.row.details?.filmName || '-' }}</span>
                    <span :class="styles.filmSub">{{ scope.row.action === 'ADD_WATCHLIST' ? t('logs.addedWatchlist') : t('logs.followedFilm') }}</span>
                  </div>
                </div>

                <!-- Search -->
                <div v-else-if="scope.row.action === 'SEARCH_FILM'" :class="styles.simpleSummary">
                  <span>{{ t('logs.searchedFilm') }}: </span>
                  <el-tag size="small" type="primary">"{{ scope.row.details?.keyword }}"</el-tag>
                  <span v-if="scope.row.details?.resultsCount !== undefined" :class="styles.textSecondary">
                    ({{ scope.row.details.resultsCount }} kết quả)
                  </span>
                </div>

                <!-- Comment -->
                <div v-else-if="scope.row.action === 'POST_COMMENT'" :class="styles.simpleSummary">
                  <span>{{ t('logs.commentedFilm') }} <strong>{{ scope.row.details?.filmName }}</strong>: </span>
                  <em>"{{ scope.row.details?.content }}"</em>
                </div>

                <!-- Default fallback -->
                <span v-else :class="styles.simpleSummary">
                  {{ formatDetails(scope.row.details) }}
                </span>
              </template>
            </el-table-column>
          </DataTable>

          <!-- Mobile Cards -->
          <div v-else :class="styles.mobileList">
            <article
              v-for="log in mobileLogs"
              :key="log.id"
              :class="styles.logCard"
              @click="openInspect(log)"
            >
              <div :class="styles.cardHeader">
                <div :class="styles.actorCell">
                  <el-avatar :size="24" :src="log.actorAvatar || undefined" :class="styles.actorAvatar">
                    {{ (log.actor || log.actorUsername || 'S').slice(0, 1).toUpperCase() }}
                  </el-avatar>
                  <span :class="styles.actorName">{{ log.actor || log.actorUsername || t('logs.system') }}</span>
                </div>
                <time :class="styles.relTime">{{ formatRelativeTime(log.createdAt) }}</time>
              </div>

              <div>
                <el-tag :type="getActionType(log.action)" size="small" :class="styles.actionTag">
                  <el-icon><component :is="getActionIcon(log.action)" /></el-icon>
                  {{ formatActionName(log.action) }}
                </el-tag>
              </div>

              <!-- Summary item -->
              <div v-if="log.action === 'WATCH_FILM' && log.details" :class="styles.summaryCell">
                <img
                  v-if="log.details.posterUrl"
                  :src="log.details.posterUrl"
                  :alt="log.details.filmName"
                  :class="styles.filmThumb"
                  loading="lazy"
                />
                <div :class="styles.filmMeta">
                  <span :class="styles.filmTitle">{{ log.details.filmName }}</span>
                  <span :class="styles.filmSub">{{ log.details.episodeName }} {{ log.details.positionSec ? '• ' + formatDuration(log.details.positionSec) : '' }}</span>
                </div>
              </div>
              <div v-else :class="styles.simpleSummary">
                {{ formatDetails(log.details) }}
              </div>
            </article>

            <div v-if="pending" :class="styles.loadingMore">{{ t('common.loading') }}</div>
          </div>
        </div>
      </ClientOnly>
    </div>

    <!-- Inspect Drawer -->
    <el-drawer
      v-model="inspectDrawer"
      :title="t('logs.inspectTitle')"
      size="420px"
      direction="rtl"
    >
      <div v-if="selectedLog" :class="styles.drawerBody">
        <!-- Actor profile -->
        <div :class="styles.drawerActorCard">
          <el-avatar :size="48" :src="selectedLog.actorAvatar || undefined">
            {{ (selectedLog.actor || selectedLog.actorUsername || 'S').slice(0, 1).toUpperCase() }}
          </el-avatar>
          <div :class="styles.drawerActorMeta">
            <span :class="styles.drawerActorName">{{ selectedLog.actor || selectedLog.actorUsername || t('logs.system') }}</span>
            <span v-if="selectedLog.actorEmail" :class="styles.drawerActorEmail">{{ selectedLog.actorEmail }}</span>
            <span v-if="selectedLog.actorUsername" :class="styles.actorUsername">@{{ selectedLog.actorUsername }}</span>
          </div>
        </div>

        <!-- Meta info -->
        <div>
          <div :class="styles.sectionLabel">{{ t('logs.details') }}</div>
          <div :class="styles.infoGrid">
            <div :class="styles.infoItem">
              <span :class="styles.infoKey">{{ t('logs.action') }}</span>
              <el-tag :type="getActionType(selectedLog.action)" size="small">
                {{ selectedLog.action }}
              </el-tag>
            </div>
            <div :class="styles.infoItem">
              <span :class="styles.infoKey">{{ t('logs.resource') }}</span>
              <span :class="styles.infoVal">{{ selectedLog.resource || '-' }}</span>
            </div>
            <div :class="styles.infoItem">
              <span :class="styles.infoKey">{{ t('logs.time') }}</span>
              <span :class="styles.infoVal">{{ formatDateTime(selectedLog.createdAt) }}</span>
            </div>
            <div :class="styles.infoItem">
              <span :class="styles.infoKey">Log ID</span>
              <span :class="styles.infoVal" style="font-size: 11px;">{{ selectedLog.id.slice(0, 12) }}...</span>
            </div>
          </div>
        </div>

        <!-- Raw JSON Payload -->
        <div>
          <div :class="styles.sectionLabel">Payload JSON</div>
          <div :class="styles.payloadBox">
            <el-button
              size="small"
              :class="styles.copyBtn"
              @click="copyPayload"
            >
              {{ copied ? t('logs.copied') : t('logs.copyPayload') }}
            </el-button>
            <pre>{{ JSON.stringify(selectedLog.details, null, 2) }}</pre>
          </div>
        </div>
      </div>
    </el-drawer>
  </div>
</template>

<script setup lang="ts">
import styles from './logs.module.scss';
import { ref, computed, watch, onMounted, inject, type Ref } from 'vue';
import {
  Search,
  VideoPlay,
  Star,
  ChatDotRound,
  Key,
  Setting,
  Delete
} from '@element-plus/icons-vue';
import { useAppStore } from '~/stores/app';
import { useDateTime } from '~/composables/useDateTime';
import { useInfiniteScroll } from '@vueuse/core';

interface LogRow {
  id: string;
  action: string;
  resource?: string | null;
  details?: any;
  createdAt: string;
  actor?: string | null;
  actorUsername?: string | null;
  actorAvatar?: string | null;
  actorEmail?: string | null;
  actorId?: string | null;
}

const { t } = useI18n();
const appStore = useAppStore();
const { formatDateTime, localDayStartToIso, localDayEndToIso } = useDateTime();

const currentPage = ref(1);
const pageSize = ref(15);
const searchQuery = ref('');
const activeCategory = ref<'all' | 'watch' | 'engagement' | 'auth' | 'system'>('all');
const actionFilter = ref('');
const dateRange = ref<[string, string] | null>(null);
const selectedUserId = ref<string | null>(null);
const selectedUserLabel = ref<string | null>(null);

const actionOptions = computed(() => {
  const all = [
    { value: 'WATCH_FILM', label: 'Xem phim', cat: 'watch' },
    { value: 'ADD_WATCHLIST', label: 'Thêm tủ phim', cat: 'engagement' },
    { value: 'REMOVE_WATCHLIST', label: 'Xóa tủ phim', cat: 'engagement' },
    { value: 'FOLLOW_FILM', label: 'Theo dõi phim', cat: 'engagement' },
    { value: 'UNFOLLOW_FILM', label: 'Bỏ theo dõi', cat: 'engagement' },
    { value: 'POST_COMMENT', label: 'Bình luận', cat: 'engagement' },
    { value: 'SEARCH_FILM', label: 'Tìm kiếm', cat: 'engagement' },
    { value: 'LOGIN', label: 'Đăng nhập', cat: 'auth' },
    { value: 'LOGOUT', label: 'Đăng xuất', cat: 'auth' },
    { value: 'PASSWORD_CHANGE', label: 'Đổi mật khẩu', cat: 'auth' },
    { value: 'CREATE_USER', label: 'Tạo user', cat: 'system' },
    { value: 'UPDATE_USER', label: 'Sửa user', cat: 'system' },
    { value: 'DELETE_USER', label: 'Xóa user', cat: 'system' },
    { value: 'CREATE_ROLE', label: 'Tạo vai trò', cat: 'system' },
    { value: 'UPDATE_ROLE', label: 'Sửa vai trò', cat: 'system' },
    { value: 'DELETE_ROLE', label: 'Xóa vai trò', cat: 'system' },
    { value: 'UPDATE_ROLE_PERMISSIONS', label: 'Phân quyền', cat: 'system' },
    { value: 'SYNC_FILMS', label: 'Đồng bộ phim', cat: 'system' },
    { value: 'MODERATE_COMMENT', label: 'Duyệt bình luận', cat: 'system' }
  ];
  if (activeCategory.value && activeCategory.value !== 'all') {
    return all.filter((a) => a.cat === activeCategory.value);
  }
  return all;
});

const inspectDrawer = ref(false);
const selectedLog = ref<LogRow | null>(null);
const copied = ref(false);

const mobileLogs = ref<LogRow[]>([]);
const mobilePage = ref(1);
const hasMoreMobile = ref(true);
const appScrollEl = inject<Ref<HTMLElement | null>>('appScrollEl', ref(null));

const apiResponse = ref<any>(null);
const pending = ref(false);
const error = ref<any>(null);

const filterByUser = (row: LogRow) => {
  if (row.actorId) {
    selectedUserId.value = row.actorId;
    selectedUserLabel.value = `@${row.actorUsername || row.actor}`;
  } else {
    searchQuery.value = row.actorUsername || row.actor || '';
  }
};

const clearUserFilter = () => {
  selectedUserId.value = null;
  selectedUserLabel.value = null;
};

const openInspect = (row: LogRow) => {
  selectedLog.value = row;
  copied.value = false;
  inspectDrawer.value = true;
};

const copyPayload = async () => {
  if (!selectedLog.value?.details) return;
  try {
    await navigator.clipboard.writeText(JSON.stringify(selectedLog.value.details, null, 2));
    copied.value = true;
    setTimeout(() => { copied.value = false; }, 2000);
  } catch {
    // fallback ignore
  }
};

const formatRelativeTime = (isoString: string) => {
  if (!isoString) return '';
  const now = Date.now();
  const time = new Date(isoString).getTime();
  const diffSec = Math.floor((now - time) / 1000);

  if (diffSec < 45) return 'Vừa xong';
  if (diffSec < 3600) return `${Math.floor(diffSec / 60)} phút trước`;
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)} giờ trước`;
  if (diffSec < 604800) return `${Math.floor(diffSec / 86400)} ngày trước`;
  return formatDateTime(isoString).split(' ')[0];
};

const formatDuration = (sec?: number) => {
  if (!sec) return '';
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${s < 10 ? '0' : ''}${s}`;
};

const formatActionName = (action: string) => {
  const map: Record<string, string> = {
    WATCH_FILM: 'Xem phim',
    ADD_WATCHLIST: 'Thêm tủ phim',
    REMOVE_WATCHLIST: 'Xóa tủ phim',
    FOLLOW_FILM: 'Theo dõi phim',
    UNFOLLOW_FILM: 'Bỏ theo dõi',
    POST_COMMENT: 'Bình luận',
    SEARCH_FILM: 'Tìm kiếm',
    LOGIN: 'Đăng nhập',
    LOGOUT: 'Đăng xuất',
    PASSWORD_CHANGE: 'Đổi mật khẩu',
    CREATE_USER: 'Tạo user',
    UPDATE_USER: 'Sửa user',
    DELETE_USER: 'Xóa user',
    CREATE_ROLE: 'Tạo vai trò',
    UPDATE_ROLE: 'Sửa vai trò',
    DELETE_ROLE: 'Xóa vai trò',
    UPDATE_ROLE_PERMISSIONS: 'Phân quyền',
    SYNC_FILMS: 'Đồng bộ phim',
    MODERATE_COMMENT: 'Duyệt bình luận'
  };
  return map[action] || action;
};

const getActionIcon = (action: string) => {
  if (action.includes('WATCH')) return VideoPlay;
  if (action.includes('WATCHLIST') || action.includes('FOLLOW')) return Star;
  if (action.includes('COMMENT')) return ChatDotRound;
  if (action.includes('LOGIN') || action.includes('PASSWORD') || action.includes('TOKEN')) return Key;
  if (action.includes('DELETE')) return Delete;
  return Setting;
};

const getActionType = (action: string) => {
  if (action.includes('DELETE') || action.includes('ERROR') || action.includes('REMOVE')) return 'danger';
  if (action.includes('UPDATE') || action.includes('MODERATE')) return 'warning';
  if (action.includes('CREATE') || action.includes('ADD') || action === 'WATCH_FILM') return 'success';
  if (action === 'LOGIN' || action.includes('FOLLOW')) return 'primary';
  return 'info';
};

const formatDetails = (value?: any) => {
  if (!value) return '-';
  if (typeof value === 'string') return value;
  if (typeof value === 'object') {
    return Object.entries(value)
      .map(([key, val]) => `${key}: ${String(val)}`)
      .join(', ');
  }
  return String(value);
};

const fetchData = async (isLoadMore = false) => {
  pending.value = true;
  error.value = null;

  try {
    const pageToFetch = appStore.isMobile ? (isLoadMore ? mobilePage.value + 1 : 1) : currentPage.value;
    const params: Record<string, any> = {
      page: pageToFetch,
      pageSize: pageSize.value
    };

    if (searchQuery.value) params.search = searchQuery.value;
    if (activeCategory.value && activeCategory.value !== 'all') params.category = activeCategory.value;
    if (actionFilter.value) params.action = actionFilter.value;
    if (selectedUserId.value) params.userId = selectedUserId.value;
    if (dateRange.value?.[0]) params.startDate = localDayStartToIso(dateRange.value[0]);
    if (dateRange.value?.[1]) params.endDate = localDayEndToIso(dateRange.value[1]);

    const res = await useApiFetch('/api/logs', {
      params,
      credentials: 'include'
    });

    apiResponse.value = res;

    if (appStore.isMobile) {
      if (!isLoadMore) {
        mobileLogs.value = res.data || [];
        mobilePage.value = 1;
      } else {
        mobileLogs.value.push(...(res.data || []));
        mobilePage.value = pageToFetch;
      }
      hasMoreMobile.value = mobileLogs.value.length < (res.total || 0);
    }
  } catch (err: any) {
    error.value = err;
    console.error('Fetch Logs Error:', err);
  } finally {
    pending.value = false;
  }
};

const loadMore = () => {
  if (!appStore.isMobile) return;
  if (pending.value || !hasMoreMobile.value) return;
  fetchData(true);
};

useInfiniteScroll(
  appScrollEl,
  () => {
    if (!appStore.isMobile) return;
    if (!pending.value && hasMoreMobile.value) loadMore();
  },
  { distance: 50 }
);

onMounted(() => fetchData());

watch(activeCategory, () => {
  actionFilter.value = '';
});

watch([currentPage, pageSize, searchQuery, activeCategory, actionFilter, selectedUserId, dateRange], () => fetchData());
usePageRefresh(() => fetchData());
</script>
