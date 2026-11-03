<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="errorMessage" show-icon :class="styles.alert" closable @close="error = null" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <p :class="styles.textSecondary">{{ t('featured.hint') }}</p>
        <el-button v-if="canCreate" type="primary" :icon="Plus" @click="openCreate">{{ t('featured.add') }}</el-button>
      </div>

      <ClientOnly>
        <div :class="styles.contentArea">
          <DataTable
            v-if="!appStore.isMobile"
            :data="rows"
            :total="0"
            :loading="pending"
            row-key="id"
          >
            <el-table-column :label="t('featured.film')" min-width="280">
              <template #default="scope">
                <div :class="styles.filmCell">
                  <img
                    :src="scope.row.film?.thumbUrl || scope.row.film?.posterUrl || ''"
                    :alt="scope.row.film?.name || ''"
                    :class="styles.thumb"
                  />
                  <div :class="styles.filmMeta">
                    <strong>{{ scope.row.film?.name || '—' }}</strong>
                    <span>{{ scope.row.film?.slug || '—' }}</span>
                  </div>
                </div>
              </template>
            </el-table-column>
            <el-table-column prop="section" :label="t('featured.section')" width="140" />
            <el-table-column prop="sortOrder" :label="t('featured.sortOrder')" width="100" />
            <el-table-column :label="t('common.actions')" min-width="110" width="110" align="right">
              <template #default="scope">
                <el-button
                  v-if="canDelete"
                  type="danger"
                  link
                  :icon="Delete"
                  @click="onDelete(scope.row as FeaturedRow)"
                />
              </template>
            </el-table-column>
          </DataTable>

          <div v-else :class="styles.mobileList">
            <article v-for="row in rows" :key="row.id" :class="styles.itemCard">
              <div :class="styles.filmCell">
                <img
                  :src="row.film?.thumbUrl || row.film?.posterUrl || ''"
                  :alt="row.film?.name || ''"
                  :class="styles.thumb"
                />
                <div :class="styles.filmMeta">
                  <strong>{{ row.film?.name || '—' }}</strong>
                  <span>{{ row.section }} · #{{ row.sortOrder }}</span>
                </div>
              </div>
              <div :class="styles.cardActions">
                <el-button v-if="canDelete" type="danger" link :icon="Delete" @click="onDelete(row)" />
              </div>
            </article>
            <div v-if="!pending && !rows.length" :class="styles.empty">{{ t('featured.empty') }}</div>
          </div>
        </div>
      </ClientOnly>
    </div>

    <el-dialog v-model="dialogVisible" :title="t('featured.createTitle')" width="480px" destroy-on-close @closed="resetForm">
      <el-form ref="formRef" :model="form" :rules="formRules" label-position="top" @submit.prevent>
        <el-form-item :label="t('featured.filmSlug')" prop="filmSlug">
          <el-input v-model="form.filmSlug" :placeholder="t('featured.filmSlugHint')" />
        </el-form-item>
        <el-form-item :label="t('featured.section')" prop="section">
          <el-select v-model="form.section" style="width: 100%">
            <el-option :label="t('featured.sectionHomeHot')" value="home_hot" />
          </el-select>
        </el-form-item>
        <el-form-item :label="t('featured.sortOrder')">
          <el-input-number v-model="form.sortOrder" :min="0" :max="9999" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">{{ t('common.cancel') }}</el-button>
        <el-button type="primary" :loading="saving" @click="onSubmit">{{ t('featured.createSubmit') }}</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import styles from '../adminContent.module.scss'
import { ref, reactive, computed, onMounted } from 'vue'
import { Plus, Delete } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import { useAppStore } from '~/stores/app'
import { useAuthStore } from '~/stores/auth'

interface FeaturedRow {
  id: string
  section: string
  sortOrder: number
  film?: {
    slug: string
    name: string
    thumbUrl?: string | null
    posterUrl?: string | null
  } | null
}

const { t } = useI18n()
const appStore = useAppStore()
const authStore = useAuthStore()
useHead({ title: () => t('pages.featured') })

const canCreate = computed(() => authStore.hasPermission('create:featured'))
const canDelete = computed(() => authStore.hasPermission('delete:featured'))

const rows = ref<FeaturedRow[]>([])
const pending = ref(false)
const error = ref<any>(null)
const dialogVisible = ref(false)
const saving = ref(false)
const formRef = ref<FormInstance>()
const form = reactive({ filmSlug: '', section: 'home_hot', sortOrder: 0 })

const formRules = computed<FormRules>(() => ({
  filmSlug: [{ required: true, message: t('featured.requiredSlug'), trigger: 'blur' }],
  section: [{ required: true, message: t('featured.requiredSection'), trigger: 'change' }]
}))

const errorMessage = computed(() => error.value?.data?.detail || error.value?.message || String(error.value || ''))

const resetForm = () => {
  form.filmSlug = ''
  form.section = 'home_hot'
  form.sortOrder = 0
}

const fetchData = async () => {
  pending.value = true
  error.value = null
  try {
    const res = await useApiFetch('/api/admin/featured', { params: { section: 'home_hot' } })
    rows.value = res.data || []
  } catch (err: any) {
    error.value = err
  } finally {
    pending.value = false
  }
}

const openCreate = () => {
  resetForm()
  dialogVisible.value = true
}

const onSubmit = async () => {
  const ok = await formRef.value?.validate().catch(() => false)
  if (!ok) return
  saving.value = true
  try {
    await useApiFetch('/api/admin/featured', {
      method: 'POST',
      body: {
        filmSlug: form.filmSlug.trim(),
        section: form.section,
        sortOrder: form.sortOrder
      }
    })
    ElMessage.success(t('featured.created'))
    dialogVisible.value = false
    await fetchData()
  } catch (err: any) {
    ElMessage.error(err?.data?.detail || t('common.actionFailed'))
  } finally {
    saving.value = false
  }
}

const onDelete = async (row: FeaturedRow) => {
  try {
    await ElMessageBox.confirm(
      t('featured.deleteConfirm', { name: row.film?.name || row.id }),
      t('common.confirmDelete'),
      { type: 'warning', confirmButtonText: t('common.delete'), cancelButtonText: t('common.cancel') }
    )
    await useApiFetch(`/api/admin/featured/${row.id}`, { method: 'DELETE' })
    ElMessage.success(t('featured.deleted'))
    await fetchData()
  } catch (err: any) {
    if (err === 'cancel' || err === 'close') return
    ElMessage.error(err?.data?.detail || t('featured.deleteFailed'))
  }
}

onMounted(() => fetchData())
usePageRefresh(() => fetchData())
</script>
