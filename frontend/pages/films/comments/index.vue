<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="errorMessage" show-icon :class="styles.alert" closable @close="error = null" />

    <div :class="styles.premiumCard">
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
            <el-table-column prop="createdAt" :label="t('commentsAdmin.time')" min-width="160">
              <template #default="scope">
                <span :class="styles.textSecondary">{{ formatDateTime(scope.row.createdAt) }}</span>
              </template>
            </el-table-column>
            <el-table-column prop="username" :label="t('commentsAdmin.user')" min-width="130" show-overflow-tooltip />
            <el-table-column :label="t('commentsAdmin.film')" min-width="180" show-overflow-tooltip>
              <template #default="scope">
                <div :class="styles.filmMeta">
                  <strong>{{ scope.row.filmName || '—' }}</strong>
                  <span>{{ scope.row.filmSlug || '' }}</span>
                </div>
              </template>
            </el-table-column>
            <el-table-column :label="t('commentsAdmin.body')" min-width="280" show-overflow-tooltip>
              <template #default="scope">
                <span :class="styles.commentBody">{{ scope.row.body }}</span>
              </template>
            </el-table-column>
            <el-table-column :label="t('commentsAdmin.hidden')" width="88" align="center">
              <template #default="scope">
                <el-switch
                  :model-value="scope.row.isHidden"
                  :disabled="!canUpdate || savingId === scope.row.id"
                  @change="(val: string | number | boolean) => onToggleHidden(scope.row as CommentRow, Boolean(val))"
                />
              </template>
            </el-table-column>
            <el-table-column :label="t('common.actions')" min-width="110" width="110" align="center" fixed="right">
              <template #default="scope">
                <el-button
                  v-if="canDelete"
                  type="danger"
                  link
                  :icon="Delete"
                  @click="onDelete(scope.row as CommentRow)"
                />
              </template>
            </el-table-column>
          </DataTable>

          <div v-else :class="styles.mobileList">
            <article v-for="row in mobileItems" :key="row.id" :class="styles.itemCard">
              <div :class="styles.cardRow">
                <strong>{{ row.username }}</strong>
                <span :class="styles.textSecondary">{{ formatDateTime(row.createdAt) }}</span>
              </div>
              <div :class="styles.filmMeta">
                <span>{{ row.filmName || row.filmSlug || '—' }}</span>
              </div>
              <p :class="styles.commentBody">{{ row.body }}</p>
              <div :class="styles.cardRow">
                <span>{{ t('commentsAdmin.hidden') }}</span>
                <div :class="styles.cardActions">
                  <el-switch
                    :model-value="row.isHidden"
                    :disabled="!canUpdate || savingId === row.id"
                    @change="(val: string | number | boolean) => onToggleHidden(row, Boolean(val))"
                  />
                  <el-button v-if="canDelete" type="danger" link :icon="Delete" @click="onDelete(row)" />
                </div>
              </div>
            </article>
            <div v-if="pending" :class="styles.loadingMore">{{ t('common.loading') }}</div>
            <div v-else-if="!mobileItems.length" :class="styles.empty">{{ t('commentsAdmin.empty') }}</div>
          </div>
        </div>
      </ClientOnly>
    </div>
  </div>
</template>

<script setup lang="ts">
import styles from '../adminContent.module.scss'
import { ref, computed, watch, onMounted, inject, type Ref } from 'vue'
import { Delete } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useAppStore } from '~/stores/app'
import { useAuthStore } from '~/stores/auth'
import { useDateTime } from '~/composables/useDateTime'
import { useInfiniteScroll } from '@vueuse/core'

interface CommentRow {
  id: string
  body: string
  username: string
  createdAt: string
  isHidden: boolean
  filmSlug?: string | null
  filmName?: string | null
}

const { t } = useI18n()
const appStore = useAppStore()
const authStore = useAuthStore()
const { formatDateTime } = useDateTime()
useHead({ title: () => t('pages.commentsAdmin') })

const canUpdate = computed(() => authStore.hasPermission('update:comments'))
const canDelete = computed(() => authStore.hasPermission('delete:comments'))

const currentPage = ref(1)
const pageSize = ref(20)
const apiResponse = ref<{ data: CommentRow[]; total: number } | null>(null)
const pending = ref(false)
const error = ref<any>(null)
const savingId = ref<string | null>(null)
const mobileItems = ref<CommentRow[]>([])
const mobilePage = ref(1)
const hasMoreMobile = ref(true)
const appScrollEl = inject<Ref<HTMLElement | null>>('appScrollEl', ref(null))

const errorMessage = computed(() => error.value?.data?.detail || error.value?.message || String(error.value || ''))

const fetchData = async (isLoadMore = false) => {
  pending.value = true
  error.value = null
  try {
    const pageToFetch = appStore.isMobile ? (isLoadMore ? mobilePage.value + 1 : 1) : currentPage.value
    const res = await useApiFetch('/api/admin/comments', {
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

const onToggleHidden = async (row: CommentRow, hidden: boolean) => {
  savingId.value = row.id
  try {
    await useApiFetch(`/api/admin/comments/${row.id}`, {
      method: 'PATCH',
      params: { isHidden: hidden }
    })
    row.isHidden = hidden
    ElMessage.success(hidden ? t('commentsAdmin.hid') : t('commentsAdmin.shown'))
  } catch (err: any) {
    ElMessage.error(err?.data?.detail || t('common.actionFailed'))
  } finally {
    savingId.value = null
  }
}

const onDelete = async (row: CommentRow) => {
  try {
    await ElMessageBox.confirm(t('commentsAdmin.deleteConfirm'), t('common.confirmDelete'), {
      type: 'warning',
      confirmButtonText: t('common.delete'),
      cancelButtonText: t('common.cancel')
    })
    await useApiFetch(`/api/admin/comments/${row.id}`, { method: 'DELETE' })
    ElMessage.success(t('commentsAdmin.deleted'))
    await fetchData()
  } catch (err: any) {
    if (err === 'cancel' || err === 'close') return
    ElMessage.error(err?.data?.detail || t('common.actionFailed'))
  }
}

useInfiniteScroll(appScrollEl, () => {
  if (!appStore.isMobile || pending.value || !hasMoreMobile.value) return
  fetchData(true)
}, { distance: 50 })

watch([currentPage, pageSize], () => { if (!appStore.isMobile) fetchData() })
onMounted(() => fetchData())
usePageRefresh(() => fetchData())
</script>
