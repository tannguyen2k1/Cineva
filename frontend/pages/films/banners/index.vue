<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="errorMessage" show-icon :class="styles.alert" closable @close="error = null" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <p :class="styles.textSecondary">{{ t('banners.hint') }}</p>
        <el-button v-if="canCreate" type="primary" :icon="Plus" @click="openCreate">{{ t('banners.add') }}</el-button>
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
            <el-table-column :label="t('banners.image')" width="120">
              <template #default="scope">
                <img :src="scope.row.imageUrl" :alt="scope.row.title" :class="styles.bannerPreview" />
              </template>
            </el-table-column>
            <el-table-column prop="title" :label="t('banners.title')" min-width="160" />
            <el-table-column prop="filmSlug" :label="t('banners.filmSlug')" min-width="140">
              <template #default="scope">{{ scope.row.filmSlug || '—' }}</template>
            </el-table-column>
            <el-table-column prop="sortOrder" :label="t('banners.sortOrder')" width="90" />
            <el-table-column :label="t('common.status')" width="110">
              <template #default="scope">
                <el-switch
                  :model-value="scope.row.isActive"
                  :disabled="!canUpdate || savingId === scope.row.id"
                  @change="(val: string | number | boolean) => onToggleActive(scope.row as BannerRow, Boolean(val))"
                />
              </template>
            </el-table-column>
            <el-table-column :label="t('common.actions')" width="120" align="right">
              <template #default="scope">
                <el-button v-if="canUpdate" type="primary" link :icon="Edit" @click="openEdit(scope.row as BannerRow)" />
                <el-button v-if="canDelete" type="danger" link :icon="Delete" @click="onDelete(scope.row as BannerRow)" />
              </template>
            </el-table-column>
          </DataTable>

          <div v-else :class="styles.mobileList">
            <article v-for="row in rows" :key="row.id" :class="styles.itemCard">
              <div :class="styles.filmCell">
                <img :src="row.imageUrl" :alt="row.title" :class="styles.bannerPreview" />
                <div :class="styles.filmMeta">
                  <strong>{{ row.title }}</strong>
                  <span>{{ row.filmSlug || t('banners.customOnly') }}</span>
                </div>
              </div>
              <div :class="styles.cardActions">
                <el-switch
                  :model-value="row.isActive"
                  :disabled="!canUpdate || savingId === row.id"
                  @change="(val: string | number | boolean) => onToggleActive(row, Boolean(val))"
                />
                <el-button v-if="canUpdate" type="primary" link :icon="Edit" @click="openEdit(row)" />
                <el-button v-if="canDelete" type="danger" link :icon="Delete" @click="onDelete(row)" />
              </div>
            </article>
            <div v-if="!pending && !rows.length" :class="styles.empty">{{ t('banners.empty') }}</div>
          </div>
        </div>
      </ClientOnly>
    </div>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? t('banners.editTitle') : t('banners.createTitle')"
      width="520px"
      destroy-on-close
      @closed="resetForm"
    >
      <el-form ref="formRef" :model="form" :rules="formRules" label-position="top" @submit.prevent>
        <el-form-item :label="t('banners.title')" prop="title">
          <el-input v-model="form.title" />
        </el-form-item>
        <el-form-item :label="t('banners.imageUrl')" prop="imageUrl">
          <el-input v-model="form.imageUrl" placeholder="https://..." />
        </el-form-item>
        <el-form-item :label="t('banners.filmSlug')" prop="filmSlug">
          <el-input v-model="form.filmSlug" :placeholder="t('banners.filmSlugHint')" />
        </el-form-item>
        <el-form-item :label="t('banners.linkUrl')">
          <el-input v-model="form.linkUrl" placeholder="/phim/... hoặc https://..." />
        </el-form-item>
        <el-form-item :label="t('banners.sortOrder')">
          <el-input-number v-model="form.sortOrder" :min="0" :max="9999" />
        </el-form-item>
        <el-form-item :label="t('common.status')">
          <el-switch v-model="form.isActive" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">{{ t('common.cancel') }}</el-button>
        <el-button type="primary" :loading="saving" @click="onSubmit">
          {{ isEdit ? t('common.saveChanges') : t('banners.createSubmit') }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import styles from '../adminContent.module.scss'
import { ref, reactive, computed, onMounted } from 'vue'
import { Plus, Edit, Delete } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import { useAppStore } from '~/stores/app'
import { useAuthStore } from '~/stores/auth'

interface BannerRow {
  id: string
  title: string
  imageUrl: string
  linkUrl?: string | null
  filmSlug?: string | null
  sortOrder: number
  isActive: boolean
}

const { t } = useI18n()
const appStore = useAppStore()
const authStore = useAuthStore()
useHead({ title: () => t('pages.banners') })

const canCreate = computed(() => authStore.hasPermission('create:banners'))
const canUpdate = computed(() => authStore.hasPermission('update:banners'))
const canDelete = computed(() => authStore.hasPermission('delete:banners'))

const rows = ref<BannerRow[]>([])
const pending = ref(false)
const error = ref<any>(null)
const savingId = ref<string | null>(null)
const dialogVisible = ref(false)
const isEdit = ref(false)
const saving = ref(false)
const formRef = ref<FormInstance>()
const editingId = ref<string | null>(null)

const form = reactive({
  title: '',
  imageUrl: '',
  filmSlug: '',
  linkUrl: '',
  sortOrder: 0,
  isActive: true
})

const formRules = computed<FormRules>(() => ({
  title: [{ required: true, message: t('banners.requiredTitle'), trigger: 'blur' }],
  imageUrl: [{ required: true, message: t('banners.requiredImage'), trigger: 'blur' }]
}))

const errorMessage = computed(() => error.value?.data?.detail || error.value?.message || String(error.value || ''))

const resetForm = () => {
  form.title = ''
  form.imageUrl = ''
  form.filmSlug = ''
  form.linkUrl = ''
  form.sortOrder = 0
  form.isActive = true
  editingId.value = null
  isEdit.value = false
}

const fetchData = async () => {
  pending.value = true
  error.value = null
  try {
    const res = await useApiFetch('/api/admin/banners')
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

const openEdit = (row: BannerRow) => {
  isEdit.value = true
  editingId.value = row.id
  form.title = row.title
  form.imageUrl = row.imageUrl
  form.filmSlug = row.filmSlug || ''
  form.linkUrl = row.linkUrl || ''
  form.sortOrder = row.sortOrder
  form.isActive = row.isActive
  dialogVisible.value = true
}

const onSubmit = async () => {
  const ok = await formRef.value?.validate().catch(() => false)
  if (!ok) return
  saving.value = true
  try {
    const body = {
      title: form.title.trim(),
      imageUrl: form.imageUrl.trim(),
      filmSlug: form.filmSlug.trim() || null,
      linkUrl: form.linkUrl.trim() || null,
      sortOrder: form.sortOrder,
      isActive: form.isActive
    }
    if (isEdit.value && editingId.value) {
      await useApiFetch(`/api/admin/banners/${editingId.value}`, { method: 'PATCH', body })
      ElMessage.success(t('banners.updated'))
    } else {
      await useApiFetch('/api/admin/banners', { method: 'POST', body })
      ElMessage.success(t('banners.created'))
    }
    dialogVisible.value = false
    await fetchData()
  } catch (err: any) {
    ElMessage.error(err?.data?.detail || t('common.actionFailed'))
  } finally {
    saving.value = false
  }
}

const onToggleActive = async (row: BannerRow, active: boolean) => {
  savingId.value = row.id
  try {
    await useApiFetch(`/api/admin/banners/${row.id}`, {
      method: 'PATCH',
      body: { isActive: active }
    })
    row.isActive = active
  } catch (err: any) {
    ElMessage.error(err?.data?.detail || t('common.actionFailed'))
  } finally {
    savingId.value = null
  }
}

const onDelete = async (row: BannerRow) => {
  try {
    await ElMessageBox.confirm(t('banners.deleteConfirm', { name: row.title }), t('common.confirmDelete'), {
      type: 'warning',
      confirmButtonText: t('common.delete'),
      cancelButtonText: t('common.cancel')
    })
    await useApiFetch(`/api/admin/banners/${row.id}`, { method: 'DELETE' })
    ElMessage.success(t('banners.deleted'))
    await fetchData()
  } catch (err: any) {
    if (err === 'cancel' || err === 'close') return
    ElMessage.error(err?.data?.detail || t('banners.deleteFailed'))
  }
}

onMounted(() => fetchData())
usePageRefresh(() => fetchData())
</script>
