<template>
  <div :class="styles.pageContainer">
    <el-alert
      v-if="error"
      type="error"
      :title="errorMessage"
      show-icon
      :class="styles.alert"
      closable
      @close="error = null"
    />

    <div :class="styles.premiumCard">
      <section :class="styles.actionsPanel">
        <div :class="styles.actionsCopy">
          <h2 :class="styles.actionsTitle">{{ t('sync.actionsTitle') }}</h2>
          <p :class="styles.actionsHint">{{ t('sync.scheduleHint') }}</p>
        </div>
        <div :class="styles.actionButtons">
          <el-button
            v-if="canRun"
            type="primary"
            :icon="Refresh"
            :loading="runningIncremental"
            :disabled="busy"
            @click="runIncremental"
          >
            {{ t('sync.runIncremental') }}
          </el-button>
          <el-button
            v-if="canRun"
            :icon="Collection"
            :loading="runningCatalog"
            :disabled="busy"
            @click="runCatalog"
          >
            {{ t('sync.runCatalog') }}
          </el-button>
          <el-button :icon="RefreshRight" :disabled="busy || pending" @click="fetchData()">
            {{ t('common.refresh') }}
          </el-button>
        </div>
      </section>

      <div :class="styles.sectionHeader">
        <h3 :class="styles.sectionTitle">{{ t('sync.historyTitle') }}</h3>
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
            <el-table-column prop="startedAt" :label="t('sync.startedAt')" width="180">
              <template #default="scope">
                <span :class="styles.textSecondary">{{ formatDateTime(scope.row.startedAt) }}</span>
              </template>
            </el-table-column>
            <el-table-column prop="jobType" :label="t('sync.jobType')" width="140">
              <template #default="scope">
                {{ jobTypeLabel(scope.row.jobType) }}
              </template>
            </el-table-column>
            <el-table-column prop="status" :label="t('common.status')" width="120">
              <template #default="scope">
                <el-tag :type="statusType(scope.row.status)" size="small" effect="light">
                  {{ statusLabel(scope.row.status) }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="itemsUpserted" :label="t('sync.itemsUpserted')" width="120" align="right" />
            <el-table-column :label="t('sync.pages')" width="100" align="center">
              <template #default="scope">
                {{ formatPages(scope.row as SyncRunRow) }}
              </template>
            </el-table-column>
            <el-table-column prop="finishedAt" :label="t('sync.finishedAt')" width="180">
              <template #default="scope">
                <span :class="styles.textSecondary">
                  {{ scope.row.finishedAt ? formatDateTime(scope.row.finishedAt) : '—' }}
                </span>
              </template>
            </el-table-column>
            <el-table-column prop="error" :label="t('sync.error')" min-width="220">
              <template #default="scope">
                <span :class="styles.errorText">{{ scope.row.error || '—' }}</span>
              </template>
            </el-table-column>
          </DataTable>

          <div v-else :class="styles.mobileList">
            <article v-for="run in mobileItems" :key="run.id" :class="styles.runCard">
              <div :class="styles.cardHeader">
                <el-tag :type="statusType(run.status)" size="small" effect="light" round>
                  {{ statusLabel(run.status) }}
                </el-tag>
                <time :class="styles.runTime">{{ formatDateTime(run.startedAt) }}</time>
              </div>
              <div :class="styles.cardMain">
                <strong>{{ jobTypeLabel(run.jobType) }}</strong>
                <span>{{ t('sync.itemsUpserted') }}: {{ run.itemsUpserted }}</span>
                <span>{{ t('sync.pages') }}: {{ formatPages(run) }}</span>
              </div>
              <p v-if="run.error" :class="styles.cardError">{{ run.error }}</p>
            </article>

            <div v-if="pending" :class="styles.loadingMore">{{ t('common.loading') }}</div>
            <div v-else-if="!mobileItems.length" :class="styles.empty">{{ t('sync.empty') }}</div>
          </div>
        </div>
      </ClientOnly>
    </div>
  </div>
</template>

<script setup lang="ts">
import styles from './sync.module.scss'
import { ref, computed, watch, onMounted, inject, type Ref } from 'vue'
import { Refresh, RefreshRight, Collection } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useAppStore } from '~/stores/app'
import { useAuthStore } from '~/stores/auth'
import { useDateTime } from '~/composables/useDateTime'
import { useInfiniteScroll } from '@vueuse/core'

interface SyncRunRow {
  id: string
  jobType: string
  status: string
  pageFrom?: number | null
  pageTo?: number | null
  itemsUpserted: number
  error?: string | null
  startedAt: string
  finishedAt?: string | null
}

const SYNC_TIMEOUT_MS = 10 * 60 * 1000

const { t } = useI18n()
const appStore = useAppStore()
const authStore = useAuthStore()
const { formatDateTime } = useDateTime()

useHead({ title: () => t('pages.sync') })

const canRun = computed(() => authStore.hasPermission('create:sync'))
const canRead = computed(() => authStore.hasPermission('read:sync'))

const currentPage = ref(1)
const pageSize = ref(20)
const apiResponse = ref<{ data: SyncRunRow[]; total: number } | null>(null)
const pending = ref(false)
const error = ref<any>(null)
const runningIncremental = ref(false)
const runningCatalog = ref(false)

const mobileItems = ref<SyncRunRow[]>([])
const mobilePage = ref(1)
const hasMoreMobile = ref(true)
const appScrollEl = inject<Ref<HTMLElement | null>>('appScrollEl', ref(null))

const busy = computed(() => runningIncremental.value || runningCatalog.value)

const errorMessage = computed(() => {
  const err = error.value
  if (!err) return ''
  return err?.data?.detail || err?.message || String(err)
})

const jobTypeLabel = (jobType: string) => {
  if (jobType === 'catalog') return t('sync.jobCatalog')
  if (jobType === 'incremental') return t('sync.jobIncremental')
  return jobType
}

const statusLabel = (status: string) => {
  if (status === 'success') return t('sync.statusSuccess')
  if (status === 'failed') return t('sync.statusFailed')
  if (status === 'running') return t('sync.statusRunning')
  return status
}

const statusType = (status: string) => {
  if (status === 'success') return 'success'
  if (status === 'failed') return 'danger'
  if (status === 'running') return 'warning'
  return 'info'
}

const formatPages = (row: SyncRunRow) => {
  if (row.pageFrom == null && row.pageTo == null) return '—'
  if (row.pageFrom != null && row.pageTo != null) return `${row.pageFrom}–${row.pageTo}`
  return String(row.pageTo ?? row.pageFrom)
}

const fetchData = async (isLoadMore = false) => {
  if (!canRead.value) return
  pending.value = true
  error.value = null

  try {
    const pageToFetch = appStore.isMobile
      ? isLoadMore
        ? mobilePage.value + 1
        : 1
      : currentPage.value

    const res = await useApiFetch('/api/admin/sync/runs', {
      params: { page: pageToFetch, pageSize: pageSize.value }
    })

    apiResponse.value = res

    if (appStore.isMobile) {
      if (!isLoadMore) {
        mobileItems.value = res.data || []
        mobilePage.value = 1
      } else {
        mobileItems.value.push(...(res.data || []))
        mobilePage.value = pageToFetch
      }
      hasMoreMobile.value = mobileItems.value.length < (res.total || 0)
    }
  } catch (err: any) {
    error.value = err
  } finally {
    pending.value = false
  }
}

const runIncremental = async () => {
  try {
    await ElMessageBox.confirm(t('sync.confirmIncremental'), t('sync.runIncremental'), {
      type: 'info',
      confirmButtonText: t('sync.runIncremental'),
      cancelButtonText: t('common.cancel')
    })
  } catch {
    return
  }

  runningIncremental.value = true
  error.value = null
  try {
    const res = await useApiFetch('/api/admin/sync/run', {
      method: 'POST',
      timeout: SYNC_TIMEOUT_MS
    })
    ElMessage.success(
      t('sync.runSuccess', { count: res?.data?.itemsUpserted ?? 0 })
    )
    currentPage.value = 1
    await fetchData()
  } catch (err: any) {
    error.value = err
    ElMessage.error(err?.data?.detail || t('sync.runFailed'))
  } finally {
    runningIncremental.value = false
  }
}

const runCatalog = async () => {
  try {
    await ElMessageBox.confirm(t('sync.confirmCatalog'), t('sync.runCatalog'), {
      type: 'warning',
      confirmButtonText: t('sync.runCatalog'),
      cancelButtonText: t('common.cancel')
    })
  } catch {
    return
  }

  runningCatalog.value = true
  error.value = null
  try {
    const res = await useApiFetch('/api/admin/sync/catalog', {
      method: 'POST',
      params: { pagesPerSource: 2 },
      timeout: SYNC_TIMEOUT_MS
    })
    ElMessage.success(
      t('sync.runSuccess', { count: res?.data?.itemsUpserted ?? 0 })
    )
    currentPage.value = 1
    await fetchData()
  } catch (err: any) {
    error.value = err
    ElMessage.error(err?.data?.detail || t('sync.runFailed'))
  } finally {
    runningCatalog.value = false
  }
}

useInfiniteScroll(
  appScrollEl,
  () => {
    if (!appStore.isMobile || pending.value || !hasMoreMobile.value) return
    fetchData(true)
  },
  { distance: 50 }
)

watch([currentPage, pageSize], () => {
  if (!appStore.isMobile) fetchData()
})

onMounted(() => fetchData())
usePageRefresh(() => fetchData())
</script>
