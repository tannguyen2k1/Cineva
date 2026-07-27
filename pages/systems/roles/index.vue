<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="error.message || error" show-icon :class="styles.alert" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <div :class="styles.filterSection">
          <el-input
            v-model="searchQuery"
            :placeholder="t('roles.searchPlaceholder')"
            :prefix-icon="Search"
            :class="styles.searchInput"
            clearable
          />
        </div>
        <el-button type="primary" :icon="Plus" @click="openCreate">{{ t('roles.add') }}</el-button>
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
          <el-table-column prop="name" :label="t('roles.name')" min-width="150">
            <template #default="scope">
              <span :class="styles.fwBold">{{ scope.row.name }}</span>
            </template>
          </el-table-column>
          <el-table-column prop="description" :label="t('roles.description')" min-width="250">
            <template #default="scope">
              {{ scope.row.description || '-' }}
            </template>
          </el-table-column>
          <el-table-column prop="userCount" :label="t('roles.userCount')" width="150" align="center">
            <template #default="scope">
              <el-tag size="small" type="info">{{ scope.row.userCount }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column :label="t('common.actions')" width="160" align="right">
            <template #default="scope">
              <el-tooltip :content="t('roles.permissions')" placement="top">
                <el-button
                  type="warning"
                  link
                  :icon="Setting"
                  @click="navigateTo(`/systems/roles/${scope.row.id}/permissions`)"
                />
              </el-tooltip>
              <el-tooltip :content="t('common.edit')" placement="top">
                <el-button type="primary" link :icon="Edit" @click="openEdit(scope.row)" />
              </el-tooltip>
              <el-tooltip :content="t('common.delete')" placement="top">
                <el-button type="danger" link :icon="Delete" @click="onDelete(scope.row)" />
              </el-tooltip>
            </template>
          </el-table-column>
        </DataTable>

        <div v-else ref="mobileListRef" :class="styles.mobileList">
          <div v-for="role in mobileRoles" :key="role.id" :class="styles.roleCard">
            <div :class="styles.cardHeader">
              <div :class="styles.roleInfo">
                <div :class="styles.roleIcon">
                  <el-icon :size="20"><Setting /></el-icon>
                </div>
                <div :class="styles.roleDetails">
                  <span :class="styles.roleName">{{ role.name }}</span>
                  <span v-if="role.description" :class="styles.roleDesc">{{ role.description }}</span>
                </div>
              </div>

              <div :class="styles.cardActions">
                <el-button type="warning" link :icon="Setting" @click="navigateTo(`/systems/roles/${role.id}/permissions`)" />
                <el-button type="primary" link :icon="Edit" @click="openEdit(role)" />
                <el-button type="danger" link :icon="Delete" @click="onDelete(role)" />
              </div>
            </div>

            <div :class="styles.cardFooter">
              <span :class="styles.cardMeta">
                <el-icon><User /></el-icon>
                {{ t('roles.userCount') }}
              </span>
              <el-tag size="small" type="info" round>{{ role.userCount }}</el-tag>
            </div>
          </div>
          <div v-if="pending" :class="styles.loadingMore">{{ t('common.loading') }}</div>
        </div>
      </ClientOnly>
    </div>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? t('roles.editTitle') : t('roles.createTitle')"
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
        <el-form-item :label="t('roles.name')" prop="name">
          <el-input v-model="form.name" placeholder="Admin, Editor..." />
        </el-form-item>
        <el-form-item :label="t('roles.description')" prop="description">
          <el-input
            v-model="form.description"
            type="textarea"
            :rows="3"
            :placeholder="t('roles.description')"
          />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">{{ t('common.cancel') }}</el-button>
        <el-button type="primary" :loading="saving" @click="onSubmit">
          {{ isEdit ? t('common.saveChanges') : t('roles.createSubmit') }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import styles from './roles.module.scss';
import { ref, reactive, computed, watch, onMounted } from 'vue';
import { Plus, Edit, Delete, Setting, Search, User } from '@element-plus/icons-vue';
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus';
import { useAuthStore } from '~/stores/auth';
import { useAppStore } from '~/stores/app';
import { useInfiniteScroll } from '@vueuse/core';

interface RoleRow {
  id: string;
  name: string;
  description?: string | null;
  userCount: number;
}

const { t } = useI18n();
const authStore = useAuthStore();
const appStore = useAppStore();
const currentPage = ref(1);
const pageSize = ref(10);
const searchQuery = ref('');

const mobileRoles = ref<RoleRow[]>([]);
const mobilePage = ref(1);
const hasMoreMobile = ref(true);
const mobileListRef = ref<HTMLElement | null>(null);

const apiResponse = ref<any>(null);
const pending = ref(false);
const error = ref<any>(null);

useInfiniteScroll(
  mobileListRef,
  () => {
    if (!pending.value && hasMoreMobile.value) {
      loadMore();
    }
  },
  { distance: 50 }
);

const dialogVisible = ref(false);
const saving = ref(false);
const formRef = ref<FormInstance>();
const editingId = ref<string | null>(null);

const form = reactive({
  name: '',
  description: ''
});

const isEdit = computed(() => !!editingId.value);

const formRules = computed<FormRules>(() => ({
  name: [
    { required: true, message: t('roles.requiredName'), trigger: 'blur' },
    { min: 2, message: t('roles.minName'), trigger: 'blur' }
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
    const params: Record<string, any> = {
      page: pageToFetch,
      pageSize: pageSize.value
    };
    if (searchQuery.value) params.search = searchQuery.value;

    const res = await $fetch<any>('/api/roles', {
      params,
      headers: authHeaders()
    });

    apiResponse.value = res;
    if (appStore.isMobile) {
      if (!isLoadMore) {
        mobileRoles.value = res.data || [];
        mobilePage.value = 1;
      } else {
        mobileRoles.value.push(...(res.data || []));
        mobilePage.value = pageToFetch;
      }
      hasMoreMobile.value = mobileRoles.value.length < (res.total || 0);
    }
  } catch (err: any) {
    error.value = err;
    console.error('Fetch Roles Error:', err);
  } finally {
    pending.value = false;
  }
};

const loadMore = () => {
  if (pending.value || !hasMoreMobile.value) return;
  fetchData(true);
};

const resetForm = () => {
  editingId.value = null;
  form.name = '';
  form.description = '';
  formRef.value?.clearValidate();
};

const openCreate = () => {
  resetForm();
  dialogVisible.value = true;
};

const openEdit = (row: RoleRow) => {
  resetForm();
  editingId.value = row.id;
  form.name = row.name;
  form.description = row.description || '';
  dialogVisible.value = true;
};

const onSubmit = async () => {
  const valid = await formRef.value?.validate().catch(() => false);
  if (!valid) return;

  saving.value = true;
  try {
    if (isEdit.value) {
      await $fetch(`/api/roles/${editingId.value}`, {
        method: 'PUT',
        body: {
          name: form.name.trim(),
          description: form.description.trim() || null
        },
        headers: authHeaders()
      });
      ElMessage.success(t('roles.updated'));
    } else {
      await $fetch('/api/roles', {
        method: 'POST',
        body: {
          name: form.name.trim(),
          description: form.description.trim() || null
        },
        headers: authHeaders()
      });
      ElMessage.success(t('roles.created'));
    }
    dialogVisible.value = false;
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || t('common.actionFailed'));
  } finally {
    saving.value = false;
  }
};

const onDelete = async (row: RoleRow) => {
  if (row.userCount > 0) {
    ElMessage.warning(
      t('roles.cannotDeleteInUse', { count: row.userCount, name: row.name })
    );
    return;
  }

  try {
    await ElMessageBox.confirm(
      t('roles.deleteConfirm', { name: row.name }),
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
    await $fetch(`/api/roles/${row.id}`, {
      method: 'DELETE',
      headers: authHeaders()
    });
    ElMessage.success(t('roles.deleted'));
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || t('roles.deleteFailed'));
  }
};

onMounted(() => fetchData());
watch([currentPage, pageSize, searchQuery], () => fetchData());
usePageRefresh(() => fetchData());
</script>
