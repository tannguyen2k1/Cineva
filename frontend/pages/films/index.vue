<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="errorMessage" show-icon :class="styles.alert" closable @close="error = null" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <div :class="styles.filterSection">
          <el-input
            v-model="searchQuery"
            :placeholder="t('adminFilms.searchPlaceholder')"
            :prefix-icon="Search"
            :class="styles.searchInput"
            clearable
          />
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
            <el-table-column :label="t('adminFilms.film')" min-width="280">
              <template #default="scope">
                <div :class="styles.filmCell">
                  <img :src="scope.row.thumbUrl || scope.row.posterUrl || ''" :alt="scope.row.name" :class="styles.thumb" />
                  <div :class="styles.filmMeta">
                    <strong>{{ scope.row.name }}</strong>
                    <span>{{ scope.row.slug }}</span>
                  </div>
                </div>
              </template>
            </el-table-column>
            <el-table-column prop="year" :label="t('adminFilms.year')" width="100" min-width="100" align="center" />
            <el-table-column prop="currentEpisode" :label="t('adminFilms.episode')" width="120" />
            <el-table-column :label="t('adminFilms.visible')" width="120">
              <template #default="scope">
                <el-switch
                  :model-value="!scope.row.isHidden"
                  :disabled="!canUpdate || savingId === scope.row.slug"
                  @change="(val: string | number | boolean) => onToggleVisible(scope.row as FilmRow, Boolean(val))"
                />
              </template>
            </el-table-column>
            <el-table-column :label="t('common.actions')" min-width="110" width="110" align="right">
              <template #default="scope">
                <el-button type="primary" link @click="openPublic(scope.row.slug)">{{ t('adminFilms.view') }}</el-button>
              </template>
            </el-table-column>
          </DataTable>

          <div v-else :class="styles.mobileList">
            <article v-for="film in mobileItems" :key="film.id" :class="styles.itemCard">
              <div :class="styles.filmCell">
                <img :src="film.thumbUrl || film.posterUrl || ''" :alt="film.name" :class="styles.thumb" />
                <div :class="styles.filmMeta">
                  <strong>{{ film.name }}</strong>
                  <span>{{ film.year || '—' }} · {{ film.currentEpisode || '—' }}</span>
                </div>
              </div>
              <div :class="styles.cardRow">
                <span>{{ t('adminFilms.visible') }}</span>
                <el-switch
                  :model-value="!film.isHidden"
                  :disabled="!canUpdate || savingId === film.slug"
                  @change="(val: string | number | boolean) => onToggleVisible(film, Boolean(val))"
                />
              </div>
            </article>
            <div v-if="pending" :class="styles.loadingMore">{{ t('common.loading') }}</div>
            <div v-else-if="!mobileItems.length" :class="styles.empty">{{ t('adminFilms.empty') }}</div>
          </div>
        </div>
      </ClientOnly>
    </div>
  </div>
</template>

<script setup lang="ts">
import styles from './adminContent.module.scss'
import { ref, computed, watch, onMounted, inject, type Ref } from 'vue'
import { Search } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { useAppStore } from '~/stores/app'
import { useAuthStore } from '~/stores/auth'
import { useInfiniteScroll } from '@vueuse/core'

interface FilmRow {
  id: string
  slug: string
  name: string
  thumbUrl?: string | null
  posterUrl?: string | null
  year?: string | number | null
  currentEpisode?: string | null
  isHidden?: boolean
}

const { t } = useI18n()
const appStore = useAppStore()
const authStore = useAuthStore()
useHead({ title: () => t('pages.adminFilms') })

const canUpdate = computed(() => authStore.hasPermission('update:films'))
const currentPage = ref(1)
const pageSize = ref(24)
const searchQuery = ref('')
const apiResponse = ref<{ data: FilmRow[]; total: number } | null>(null)
const pending = ref(false)
const error = ref<any>(null)
const savingId = ref<string | null>(null)
const mobileItems = ref<FilmRow[]>([])
const mobilePage = ref(1)
const hasMoreMobile = ref(true)
const appScrollEl = inject<Ref<HTMLElement | null>>('appScrollEl', ref(null))

const errorMessage = computed(() => error.value?.data?.detail || error.value?.message || String(error.value || ''))

const fetchData = async (isLoadMore = false) => {
  pending.value = true
  error.value = null
  try {
    const pageToFetch = appStore.isMobile ? (isLoadMore ? mobilePage.value + 1 : 1) : currentPage.value
    const res = await useApiFetch('/api/admin/films', {
      params: { page: pageToFetch, pageSize: pageSize.value, q: searchQuery.value || undefined }
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

const onToggleVisible = async (row: FilmRow, visible: boolean) => {
  savingId.value = row.slug
  try {
    await useApiFetch(`/api/admin/films/${row.slug}`, {
      method: 'PATCH',
      body: { isHidden: !visible }
    })
    row.isHidden = !visible
    ElMessage.success(visible ? t('adminFilms.shown') : t('adminFilms.hidden'))
  } catch (err: any) {
    ElMessage.error(err?.data?.detail || t('common.actionFailed'))
  } finally {
    savingId.value = null
  }
}

const openPublic = (slug: string) => {
  window.open(`/phim/${slug}`, '_blank')
}

useInfiniteScroll(appScrollEl, () => {
  if (!appStore.isMobile || pending.value || !hasMoreMobile.value) return
  fetchData(true)
}, { distance: 50 })

watch([currentPage, pageSize], () => { if (!appStore.isMobile) fetchData() })
watch(searchQuery, () => {
  currentPage.value = 1
  mobilePage.value = 1
  mobileItems.value = []
  hasMoreMobile.value = true
  fetchData()
})

onMounted(() => fetchData())
usePageRefresh(() => fetchData())
</script>
