<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="error.message || error" show-icon :class="styles.alert" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <div :class="styles.filterSection">
          <el-input
            v-model="searchQuery"
            :placeholder="t('tenants.searchPlaceholder')"
            :prefix-icon="Search"
            :class="styles.searchInput"
            clearable
          />
          <el-select v-model="statusFilter" :placeholder="t('common.status')" :class="styles.filterSelect" clearable>
            <el-option :label="t('common.active')" value="active" />
            <el-option :label="t('common.inactive')" value="inactive" />
          </el-select>
        </div>
        <el-button type="primary" :icon="Plus" @click="openCreate">{{ t('tenants.add') }}</el-button>
      </div>

      <ClientOnly>
        <DataTable
          v-if="!appStore.isMobile"
          :data="apiResponse?.data || []"
          :total="apiResponse?.total || 0"
          :loading="pending"
          v-model:page-size="pageSize"
          v-model:current-page="currentPage"
          row-key="id"
        >
          <el-table-column prop="name" :label="t('tenants.name')" min-width="250">
            <template #default="scope">
              <span :class="styles.fwBold">{{ scope.row.name }}</span>
            </template>
          </el-table-column>
          <el-table-column prop="domain" :label="t('tenants.domain')" min-width="150">
            <template #default="scope">
              <span style="color: var(--text-secondary)">{{ scope.row.domain || '-' }}</span>
            </template>
          </el-table-column>
          <el-table-column prop="userCount" :label="t('tenants.userCount')" width="150" align="center">
            <template #default="scope">
              <el-tag size="small" type="info">{{ scope.row.userCount }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="isActive" :label="t('common.status')" width="120">
            <template #default="scope">
              <el-switch
                :model-value="scope.row.isActive"
                :disabled="scope.row.id === authStore.tenant_id || statusSavingId === scope.row.id"
                @change="(val: string | number | boolean) => onToggleActive(scope.row, Boolean(val))"
              />
            </template>
          </el-table-column>
          <el-table-column prop="createdAt" :label="t('tenants.createdAt')" width="150">
            <template #default="scope">
              <span style="color: var(--text-secondary)">
                {{ new Date(scope.row.createdAt).toLocaleDateString(dateLocale) }}
              </span>
            </template>
          </el-table-column>
          <el-table-column :label="t('common.actions')" width="120" align="right">
            <template #default="scope">
              <el-tooltip :content="t('common.edit')" placement="top">
                <el-button type="primary" link :icon="Edit" @click="openEdit(scope.row)" />
              </el-tooltip>
              <el-tooltip :content="t('common.delete')" placement="top">
                <el-button
                  type="danger"
                  link
                  :icon="Delete"
                  :disabled="scope.row.id === authStore.tenant_id"
                  @click="onDelete(scope.row)"
                />
              </el-tooltip>
            </template>
          </el-table-column>
        </DataTable>

        <div v-else ref="mobileListRef" :class="styles.mobileList">
          <div v-for="tenant in mobileTenants" :key="tenant.id" :class="styles.tenantCard">
            <div :class="styles.cardHeader">
              <div :class="styles.tenantInfo">
                <div :class="styles.tenantDetails">
                  <span :class="styles.tenantName">{{ tenant.name }}</span>
                  <span :class="styles.tenantDomain">{{ tenant.domain || '-' }}</span>
                </div>
              </div>

              <div :class="styles.cardActions">
                <el-button type="primary" link :icon="Edit" @click="openEdit(tenant as any)" />
                <el-button
                  type="danger"
                  link
                  :icon="Delete"
                  :disabled="tenant.id === authStore.tenant_id"
                  @click="onDelete(tenant as any)"
                />
              </div>
            </div>

            <div :class="styles.tenantUsers">
              <el-tag size="small" type="info" effect="light" round>
                {{ t('tenants.userCount') }}: {{ tenant.userCount }}
              </el-tag>
            </div>

            <div :class="styles.cardFooter">
              <span :class="styles.cardMeta">{{ t('common.status') }}</span>
              <el-switch
                :model-value="tenant.isActive"
                :disabled="tenant.id === authStore.tenant_id || statusSavingId === tenant.id"
                @change="(val: string | number | boolean) => onToggleActive(tenant as any, Boolean(val))"
              />
            </div>
          </div>

          <div v-if="pending" :class="styles.loadingMore">{{ t('common.loading') }}</div>
        </div>
      </ClientOnly>
    </div>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? t('tenants.editTitle') : t('tenants.createTitle')"
      width="480px"
      destroy-on-close
      @closed="resetForm"
    >
      <el-form
        ref="formRef"
        :model="form"
        :rules="formRules"
        label-position="top"
        @submit.prevent
      >
        <el-form-item :label="t('tenants.name')" prop="name">
          <el-input v-model="form.name" placeholder="default, acme..." />
        </el-form-item>
        <el-form-item :label="t('tenants.domain')" prop="domain">
          <el-input v-model="form.domain" placeholder="acme.local" />
        </el-form-item>
        <el-form-item :label="t('common.status')">
          <el-switch
            v-model="form.isActive"
            :active-text="t('common.active')"
            :inactive-text="t('common.locked')"
            :disabled="isEdit && form.id === authStore.tenant_id"
          />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">{{ t('common.cancel') }}</el-button>
        <el-button type="primary" :loading="saving" @click="onSubmit">
          {{ isEdit ? t('common.saveChanges') : t('tenants.createSubmit') }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import styles from './tenants.module.scss';
import { ref, reactive, computed, watch, onMounted } from 'vue';
import { Plus, Edit, Delete, Search } from '@element-plus/icons-vue';
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus';
import { useAuthStore } from '~/stores/auth';
import { useAppStore } from '~/stores/app';
import { useInfiniteScroll } from '@vueuse/core';

interface TenantRow {
  id: string;
  name: string;
  domain?: string | null;
  isActive: boolean;
  userCount: number;
  createdAt: string;
}

const { t, locale } = useI18n();
const authStore = useAuthStore();
const appStore = useAppStore();
const currentPage = ref(1);
const pageSize = ref(10);
const searchQuery = ref('');
const statusFilter = ref('');

const mobileTenants = ref<TenantRow[]>([]);
const mobilePage = ref(1);
const hasMoreMobile = ref(true);
const mobileListRef = ref<HTMLElement | null>(null);

const apiResponse = ref<any>(null);
const pending = ref(false);
const error = ref<any>(null);

const dialogVisible = ref(false);
const saving = ref(false);
const statusSavingId = ref<string | null>(null);
const formRef = ref<FormInstance>();
const editingId = ref<string | null>(null);

const form = reactive({
  id: '',
  name: '',
  domain: '',
  isActive: true
});

const isEdit = computed(() => !!editingId.value);
const dateLocale = computed(() => (locale.value === 'en' ? 'en-US' : 'vi-VN'));

const formRules = computed<FormRules>(() => ({
  name: [
    { required: true, message: t('tenants.requiredName'), trigger: 'blur' },
    { min: 2, message: t('tenants.minName'), trigger: 'blur' }
  ]
}));

const authHeaders = () => {
  const headers: Record<string, string> = {};
  if (authStore.token) headers.Authorization = `Bearer ${authStore.token}`;
  if (authStore.tenant_id) headers['x-tenant-id'] = authStore.tenant_id;
  return headers;
};

const fetchData = async (isLoadMore = false) => {
  pending.value = true;
  error.value = null;
  try {
    const pageToFetch = appStore.isMobile ? (isLoadMore ? mobilePage.value + 1 : 1) : currentPage.value;
    const params: Record<string, any> = { page: pageToFetch, pageSize: pageSize.value };
    if (searchQuery.value) params.search = searchQuery.value;
    if (statusFilter.value) params.status = statusFilter.value;

    const res = await $fetch<any>('/api/tenants', {
      params,
      headers: authHeaders()
    });
    apiResponse.value = res;

    if (appStore.isMobile) {
      if (!isLoadMore) {
        mobileTenants.value = res.data || [];
        mobilePage.value = 1;
      } else {
        mobileTenants.value.push(...(res.data || []));
        mobilePage.value = pageToFetch;
      }
      hasMoreMobile.value = mobileTenants.value.length < (res.total || 0);
    }
  } catch (err: any) {
    error.value = err;
    console.error('Fetch Tenants Error:', err);
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
  mobileListRef,
  () => {
    if (!appStore.isMobile) return;
    if (!pending.value && hasMoreMobile.value) loadMore();
  },
  { distance: 50 }
);

const resetForm = () => {
  editingId.value = null;
  form.id = '';
  form.name = '';
  form.domain = '';
  form.isActive = true;
  formRef.value?.clearValidate();
};

const openCreate = () => {
  resetForm();
  dialogVisible.value = true;
};

const openEdit = (row: TenantRow) => {
  resetForm();
  editingId.value = row.id;
  form.id = row.id;
  form.name = row.name;
  form.domain = row.domain || '';
  form.isActive = row.isActive;
  dialogVisible.value = true;
};

const onSubmit = async () => {
  const valid = await formRef.value?.validate().catch(() => false);
  if (!valid) return;

  saving.value = true;
  try {
    if (isEdit.value) {
      await $fetch(`/api/tenants/${editingId.value}`, {
        method: 'PUT',
        body: {
          name: form.name.trim(),
          domain: form.domain.trim() || null,
          isActive: form.isActive
        },
        headers: authHeaders()
      });
      ElMessage.success(t('tenants.updated'));
    } else {
      const created = await $fetch<any>('/api/tenants', {
        method: 'POST',
        body: {
          name: form.name.trim(),
          domain: form.domain.trim() || null,
          isActive: form.isActive
        },
        headers: authHeaders()
      });
      const creds = created?.data?.defaultAdmin;
      ElMessage.success(
        creds
          ? t('tenants.createdWithCreds', { username: creds.username, password: creds.password })
          : t('tenants.created')
      );
    }
    dialogVisible.value = false;
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || t('common.actionFailed'));
  } finally {
    saving.value = false;
  }
};

const onToggleActive = async (row: TenantRow, next: boolean) => {
  if (row.id === authStore.tenant_id) {
    ElMessage.warning(t('tenants.cannotLockSelf'));
    return;
  }

  statusSavingId.value = row.id;
  const prev = row.isActive;
  row.isActive = next;
  try {
    await $fetch(`/api/tenants/${row.id}`, {
      method: 'PUT',
      body: { isActive: next },
      headers: authHeaders()
    });
    ElMessage.success(next ? t('tenants.unlocked') : t('tenants.locked'));
  } catch (err: any) {
    row.isActive = prev;
    ElMessage.error(err?.data?.statusMessage || err?.message || t('users.statusFailed'));
  } finally {
    statusSavingId.value = null;
  }
};

const onDelete = async (row: TenantRow) => {
  if (row.id === authStore.tenant_id) {
    ElMessage.warning(t('tenants.cannotDeleteSelf'));
    return;
  }

  if (row.userCount > 0) {
    ElMessage.warning(
      t('tenants.cannotDeleteInUse', { count: row.userCount, name: row.name })
    );
    return;
  }

  try {
    await ElMessageBox.confirm(
      t('tenants.deleteConfirm', { name: row.name }),
      t('common.confirmDelete'),
      {
        type: 'warning',
        confirmButtonText: t('common.delete'),
        cancelButtonText: t('common.cancel')
      }
    );
  } catch {
    return;
  }

  try {
    await $fetch(`/api/tenants/${row.id}`, {
      method: 'DELETE',
      headers: authHeaders()
    });
    ElMessage.success(t('tenants.deleted'));
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || t('tenants.deleteFailed'));
  }
};

onMounted(() => fetchData());
watch([currentPage, pageSize, searchQuery, statusFilter], () => fetchData());
usePageRefresh(() => fetchData());
</script>
