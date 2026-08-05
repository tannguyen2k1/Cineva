<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="error.message || error" show-icon :class="styles.alert" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <div :class="styles.filterSection">
          <el-input
            v-model="searchQuery"
            :placeholder="t('common.search')"
            :prefix-icon="Search"
            :class="styles.searchInput"
            clearable
          />
          <el-select v-model="resourceFilter" :placeholder="t('logs.module')" :class="styles.filterSelect" clearable>
            <el-option :label="t('logs.all')" value="" />
            <el-option v-for="item in resourceOptions" :key="item" :label="item" :value="item" />
          </el-select>
          <el-select v-model="actionFilter" :placeholder="t('logs.action')" :class="styles.filterSelect" clearable>
            <el-option :label="t('logs.all')" value="" />
            <el-option v-for="item in actionOptions" :key="item" :label="item" :value="item" />
          </el-select>
          <div :class="styles.dateRangeWrap">
            <el-date-picker
              v-model="dateRange"
              type="daterange"
              :range-separator="t('logs.to')"
              :start-placeholder="t('logs.startDate')"
              :end-placeholder="t('logs.endDate')"
              value-format="YYYY-MM-DD"
              style="width: 100%"
              clearable
            />
          </div>
        </div>
      </div>

      <ClientOnly>
        <div :class="styles.contentArea">
        <DataTable
          v-if="!appStore.isMobile"
          :data="apiResponse?.data || []"
          :total="apiResponse?.total || 0"
          :loading="pending"
          v-model:page-size="pageSize"
          v-model:current-page="currentPage"
          row-key="id"
        >
          <el-table-column prop="createdAt" :label="t('logs.time')" width="180">
            <template #default="scope">
              <span :class="styles.textSecondary">{{ formatDateTime(scope.row.createdAt) }}</span>
            </template>
          </el-table-column>
          <el-table-column prop="actor" :label="t('logs.actor')" min-width="160">
            <template #default="scope">
              {{ scope.row.actor || t('logs.system') }}
            </template>
          </el-table-column>
          <el-table-column prop="action" :label="t('logs.action')" min-width="180">
            <template #default="scope">
              <el-tag :type="getActionType(scope.row.action)" size="small">
                {{ scope.row.action }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="resource" :label="t('logs.resource')" width="140">
            <template #default="scope">
              {{ scope.row.resource || '-' }}
            </template>
          </el-table-column>
          <el-table-column prop="details" :label="t('logs.details')" min-width="280">
            <template #default="scope">
              <span :class="styles.detailsText">{{ formatDetails(scope.row.details) }}</span>
            </template>
          </el-table-column>
        </DataTable>

        <div v-else :class="styles.mobileList">
          <article
            v-for="log in mobileLogs"
            :key="log.id"
            :class="[styles.logCard, styles[`tone${getActionTone(log.action)}`]]"
          >
            <div :class="styles.cardHeader">
              <el-tag :type="getActionType(log.action)" size="small" effect="light" round>
                {{ log.action }}
              </el-tag>
              <time :class="styles.logTime">{{ formatDateTime(log.createdAt) }}</time>
            </div>

            <div :class="styles.cardMain">
              <div :class="styles.actorRow">
                <el-icon :class="styles.actorIcon"><User /></el-icon>
                <span :class="styles.actorName">{{ log.actor || t('logs.system') }}</span>
              </div>
              <span v-if="log.resource" :class="styles.resourceChip">{{ log.resource }}</span>
            </div>

            <div v-if="log.details" :class="styles.detailsBox">
              <template v-if="parseDetailEntries(log.details).length">
                <span
                  v-for="item in parseDetailEntries(log.details)"
                  :key="item.key"
                  :class="styles.detailChip"
                >
                  <span :class="styles.detailKey">{{ item.key }}</span>
                  <span :class="styles.detailVal">{{ item.val }}</span>
                </span>
              </template>
              <p v-else :class="styles.detailPlain">{{ formatDetails(log.details) }}</p>
            </div>
          </article>

          <div v-if="pending" :class="styles.loadingMore">{{ t('common.loading') }}</div>
        </div>
        </div>
      </ClientOnly>
    </div>
  </div>
</template>

<script setup lang="ts">
import styles from './logs.module.scss';
import { ref, computed, watch, onMounted, inject, type Ref } from 'vue';
import { Search, User } from '@element-plus/icons-vue';
import { useAppStore } from '~/stores/app';
import { useDateTime } from '~/composables/useDateTime';
import { useInfiniteScroll } from '@vueuse/core';

interface LogRow {
  id: string;
  action: string;
  resource?: string | null;
  details?: string | null;
  createdAt: string;
  actor?: string | null;
  actorUsername?: string | null;
}

const { t } = useI18n();
const appStore = useAppStore();
const { formatDateTime, localDayStartToIso, localDayEndToIso } = useDateTime();

const currentPage = ref(1);
const pageSize = ref(10);
const searchQuery = ref('');
const resourceFilter = ref('');
const actionFilter = ref('');
const dateRange = ref<[string, string] | null>(null);

const mobileLogs = ref<LogRow[]>([]);
const mobilePage = ref(1);
const hasMoreMobile = ref(true);
const appScrollEl = inject<Ref<HTMLElement | null>>('appScrollEl', ref(null));

const apiResponse = ref<any>(null);
const pending = ref(false);
const error = ref<any>(null);

const resourceOptions = ['User', 'Role', 'Tenant', 'Auth'];
const actionOptions = [
  'LOGIN',
  'CREATE_USER',
  'UPDATE_USER',
  'DELETE_USER',
  'CREATE_ROLE',
  'UPDATE_ROLE',
  'DELETE_ROLE',
  'UPDATE_ROLE_PERMISSIONS',
  'CREATE_TENANT',
  'UPDATE_TENANT',
  'DELETE_TENANT'
];


const formatDetails = (value?: string | null) => {
  if (!value) return '-';
  try {
    const parsed = JSON.parse(value);
    if (parsed && typeof parsed === 'object') {
      return Object.entries(parsed)
        .map(([key, val]) => `${key}: ${String(val)}`)
        .join(', ');
    }
  } catch {
    // keep raw string
  }
  return value;
};

const parseDetailEntries = (value?: string | null) => {
  if (!value) return [];
  try {
    const parsed = JSON.parse(value);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return Object.entries(parsed).map(([key, val]) => ({
        key,
        val: String(val)
      }));
    }
  } catch {
    // keep as plain text below
  }
  return [];
};

const getActionType = (action: string) => {
  if (action.includes('DELETE') || action.includes('ERROR')) return 'danger';
  if (action.includes('UPDATE')) return 'warning';
  if (action.includes('CREATE')) return 'success';
  if (action === 'LOGIN') return 'primary';
  return 'info';
};

const getActionTone = (action: string) => {
  const type = getActionType(action);
  if (type === 'danger') return 'Danger';
  if (type === 'warning') return 'Warning';
  if (type === 'success') return 'Success';
  if (type === 'primary') return 'Primary';
  return 'Info';
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
    if (resourceFilter.value) params.resource = resourceFilter.value;
    if (actionFilter.value) params.action = actionFilter.value;
    if (dateRange.value?.[0]) params.startDate = localDayStartToIso(dateRange.value[0]);
    if (dateRange.value?.[1]) params.endDate = localDayEndToIso(dateRange.value[1]);

    const res = await $fetch<any>('/api/logs', {
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
watch([currentPage, pageSize, searchQuery, resourceFilter, actionFilter, dateRange], () => fetchData());
usePageRefresh(() => fetchData());
</script>
