<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="error.message || error" show-icon :class="styles.alert" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <div :class="styles.filterSection">
          <el-input
            v-model="searchQuery"
            :placeholder="t('users.searchPlaceholder')"
            :prefix-icon="Search"
            :class="styles.searchInput"
            clearable
          />
          <el-select v-model="statusFilter" :placeholder="t('common.status')" :class="styles.filterSelect" clearable>
            <el-option :label="t('common.active')" value="active" />
            <el-option :label="t('common.inactive')" value="inactive" />
          </el-select>
        </div>
        <el-button type="primary" :icon="Plus" @click="openCreate">{{ t('users.add') }}</el-button>
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
        <el-table-column prop="username" :label="t('users.username')" min-width="180">
          <template #default="scope">
            <div :class="styles.userCell">
              <UserProfile
                :username="scope.row.username"
                :avatar="scope.row.avatar"
                size="small"
                :text-class="styles.fwBold"
                :gap="12"
              />
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="fullName" :label="t('users.fullName')" min-width="200">
          <template #default="scope">
            {{ scope.row.fullName || '-' }}
          </template>
        </el-table-column>
        <el-table-column :label="t('users.roles')" min-width="200">
          <template #default="scope">
            <div style="display: flex; gap: 4px; flex-wrap: wrap;">
              <el-tag
                v-for="(role, index) in scope.row.roles"
                :key="index"
                size="small"
                :type="role === 'Admin' ? 'danger' : 'info'"
              >
                {{ role }}
              </el-tag>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="isActive" :label="t('common.status')" width="120">
          <template #default="scope">
            <el-switch
              :model-value="scope.row.isActive"
              :disabled="scope.row.id === authStore.user?.id || statusSavingId === scope.row.id"
              @change="(val: string | number | boolean) => onToggleActive(scope.row as any, Boolean(val))"
            />
          </template>
        </el-table-column>
        <el-table-column :label="t('common.actions')" width="120" align="right">
          <template #default="scope">
            <el-tooltip :content="t('common.edit')" placement="top">
              <el-button type="primary" link :icon="Edit" @click="openEdit(scope.row as any)" />
            </el-tooltip>
            <el-tooltip :content="t('common.delete')" placement="top">
              <el-button
                type="danger"
                link
                :icon="Delete"
                :disabled="scope.row.id === authStore.user?.id"
                @click="onDelete(scope.row as any)"
              />
            </el-tooltip>
          </template>
        </el-table-column>
      </DataTable>

      <div v-else :class="styles.mobileList">
        <div v-for="user in mobileUsers" :key="user.id" :class="styles.userCard">
          
          <div :class="styles.cardHeader">
            <div :class="styles.userInfo">
              <UserProfile
                :username="user.username"
                :avatar="user.avatar"
                :size="48"
                :show-name="false"
              />
              <div :class="styles.userDetails">
                <span :class="styles.userName">{{ user.username }}</span>
                <span v-if="user.fullName" :class="styles.textSecondary">{{ user.fullName }}</span>
                <div v-if="user.roles?.length" :class="styles.cardRoles">
                  <el-tag
                    v-for="(role, index) in user.roles"
                    :key="index"
                    size="small"
                    :type="role === 'Admin' ? 'danger' : 'info'"
                    effect="light"
                    round
                  >
                    {{ role }}
                  </el-tag>
                </div>
              </div>
            </div>
            
            <div :class="styles.cardActions">
              <el-button type="primary" link :icon="Edit" @click="openEdit(user as any)" />
              <el-button type="danger" link :icon="Delete" :disabled="user.id === authStore.user?.id" @click="onDelete(user as any)" />
            </div>
          </div>

          <div :class="styles.cardFooter">
            <span :class="styles.cardMeta">{{ t('common.status') }}</span>
            <el-switch
              :model-value="user.isActive"
              :disabled="user.id === authStore.user?.id || statusSavingId === user.id"
              @change="(val: string | number | boolean) => onToggleActive(user as any, Boolean(val))"
            />
          </div>
        </div>
        <div v-if="pending" :class="styles.loadingMore">{{ t('common.loading') }}</div>
      </div>
      </ClientOnly>
    </div>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? t('users.editTitle') : t('users.createTitle')"
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
        <el-form-item :label="t('users.username')" prop="username">
          <el-input
            v-model="form.username"
            placeholder="nguyenvana"
            :disabled="isEdit"
            autocomplete="off"
          />
        </el-form-item>
        <el-form-item :label="t('users.fullName')" prop="fullName">
          <el-input v-model="form.fullName" placeholder="Nguyễn Văn A" />
        </el-form-item>
        <el-form-item :label="t('users.email')" prop="email">
          <el-input v-model="form.email" placeholder="ban@congty.com" />
        </el-form-item>
        <el-form-item :label="isEdit ? t('users.passwordNew') : t('users.password')" prop="password">
          <el-input
            v-model="form.password"
            type="password"
            :placeholder="isEdit ? t('users.passwordOptional') : '••••••••'"
            show-password
            autocomplete="new-password"
          />
        </el-form-item>
        <el-form-item :label="t('users.roles')" prop="roleIds">
          <el-select
            v-model="form.roleIds"
            multiple
            filterable
            :placeholder="t('users.rolesPlaceholder')"
            style="width: 100%"
            :loading="rolesLoading"
          >
            <el-option
              v-for="role in roleOptions"
              :key="role.id"
              :label="role.name"
              :value="role.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item :label="t('common.status')">
          <el-switch
            v-model="form.isActive"
            :active-text="t('common.active')"
            :inactive-text="t('common.locked')"
            :disabled="isEdit && form.id === authStore.user?.id"
          />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">{{ t('common.cancel') }}</el-button>
        <el-button type="primary" :loading="saving" @click="onSubmit">
          {{ isEdit ? t('common.saveChanges') : t('users.createSubmit') }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import styles from './users.module.scss';
import { ref, reactive, computed, watch, onMounted, inject, type Ref } from 'vue';
import { Search, Plus, Edit, Delete } from '@element-plus/icons-vue';
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus';
import { useAuthStore } from '~/stores/auth';
import { useAppStore } from '~/stores/app';
import { useInfiniteScroll } from '@vueuse/core';

interface UserRow {
  id: string;
  username: string;
  email?: string | null;
  fullName?: string | null;
  avatar?: string | null;
  isActive: boolean;
  roles: string[];
  roleIds: string[];
}

interface RoleOption {
  id: string;
  name: string;
}

const { t } = useI18n();
const authStore = useAuthStore();
const appStore = useAppStore();
const searchQuery = ref('');
const statusFilter = ref('');
const currentPage = ref(1);
const pageSize = ref(10);

const mobileUsers = ref<UserRow[]>([]);
const mobilePage = ref(1);
const hasMoreMobile = ref(true);
const appScrollEl = inject<Ref<HTMLElement | null>>('appScrollEl', ref(null));

const apiResponse = ref<any>(null);
const pending = ref(false);
const error = ref<any>(null);

useInfiniteScroll(
  appScrollEl,
  async () => {
    if (!appStore.isMobile || pending.value || !hasMoreMobile.value) return;
    await loadMore();
  },
  {
    distance: 50,
    canLoadMore: () =>
      appStore.isMobile && !pending.value && hasMoreMobile.value
  }
);

const dialogVisible = ref(false);
const saving = ref(false);
const statusSavingId = ref<string | null>(null);
const formRef = ref<FormInstance>();
const editingId = ref<string | null>(null);

const form = reactive({
  id: '' as string,
  username: '',
  fullName: '',
  email: '',
  password: '',
  isActive: true,
  roleIds: [] as string[]
});

const isEdit = computed(() => !!editingId.value);

const formRules = computed<FormRules>(() => ({
  username: [
    { required: true, message: t('users.requiredUsername'), trigger: 'blur' },
    { min: 3, message: t('users.minUsername'), trigger: 'blur' }
  ],
  email: [
    { type: 'email', message: t('users.invalidEmail'), trigger: ['blur', 'change'] }
  ],
  password: isEdit.value
    ? [
        {
          validator: (_rule, value, callback) => {
            if (value && value.length < 6) callback(new Error(t('users.minPassword')));
            else callback();
          },
          trigger: 'blur'
        }
      ]
    : [
        { required: true, message: t('users.requiredPassword'), trigger: 'blur' },
        { min: 6, message: t('users.minPassword'), trigger: 'blur' }
      ]
}));

const roleOptions = ref<RoleOption[]>([]);
const rolesLoading = ref(false);


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
    if (statusFilter.value) params.status = statusFilter.value;

    const res = await useApiFetch('/api/users', {
      params,
      credentials: 'include'
    });
    
    apiResponse.value = res;
    if (appStore.isMobile) {
      if (!isLoadMore) {
        mobileUsers.value = res.data || [];
        mobilePage.value = 1;
      } else {
        mobileUsers.value.push(...(res.data || []));
        mobilePage.value = pageToFetch;
      }
      hasMoreMobile.value = mobileUsers.value.length < (res.total || 0);
    }
  } catch (err: any) {
    error.value = err;
    console.error('Fetch Users Error:', err);
  } finally {
    pending.value = false;
  }
};

const loadMore = async () => {
  if (pending.value || !hasMoreMobile.value) return;
  await fetchData(true);
};

const fetchRoles = async () => {
  rolesLoading.value = true;
  try {
    const res = await useApiFetch('/api/roles', {
      params: { page: 1, pageSize: 100 },
      credentials: 'include'
    });
    roleOptions.value = (res?.data || []).map((r: any) => ({
      id: r.id,
      name: r.name
    }));
  } catch (err) {
    console.error('Fetch Roles Error:', err);
  } finally {
    rolesLoading.value = false;
  }
};

const resetForm = () => {
  editingId.value = null;
  form.id = '';
  form.username = '';
  form.fullName = '';
  form.email = '';
  form.password = '';
  form.isActive = true;
  form.roleIds = [];
  formRef.value?.clearValidate();
};

const openCreate = async () => {
  resetForm();
  dialogVisible.value = true;
  await fetchRoles();
};

const openEdit = async (row: UserRow) => {
  resetForm();
  editingId.value = row.id;
  form.id = row.id;
  form.username = row.username;
  form.fullName = row.fullName || '';
  form.email = row.email || '';
  form.password = '';
  form.isActive = row.isActive;
  form.roleIds = [...(row.roleIds || [])];
  dialogVisible.value = true;
  await fetchRoles();
};

const onSubmit = async () => {
  const valid = await formRef.value?.validate().catch(() => false);
  if (!valid) return;

  saving.value = true;
  try {
    if (isEdit.value) {
      const payload: Record<string, unknown> = {
        fullName: form.fullName || null,
        email: form.email || null,
        isActive: form.isActive,
        roleIds: form.roleIds
      };
      if (form.password) payload.password = form.password;

      await useApiFetch(`/api/users/${editingId.value}`, {
        method: 'PUT',
        body: payload,
        credentials: 'include'
      });
      ElMessage.success(t('users.updated'));
    } else {
      await useApiFetch('/api/users', {
        method: 'POST',
        body: {
          username: form.username.trim(),
          password: form.password,
          fullName: form.fullName || null,
          email: form.email || null,
          isActive: form.isActive,
          roleIds: form.roleIds
        },
        credentials: 'include'
      });
      ElMessage.success(t('users.created'));
    }
    dialogVisible.value = false;
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || t('common.actionFailed'));
  } finally {
    saving.value = false;
  }
};

const onToggleActive = async (row: UserRow, next: boolean) => {
  if (row.id === authStore.user?.id) {
    ElMessage.warning(t('users.cannotLockSelf'));
    return;
  }

  statusSavingId.value = row.id;
  const prev = row.isActive;
  row.isActive = next;
  try {
    await useApiFetch(`/api/users/${row.id}`, {
      method: 'PUT',
      body: { isActive: next },
      credentials: 'include'
    });
    ElMessage.success(next ? t('users.unlocked') : t('users.locked'));
  } catch (err: any) {
    row.isActive = prev;
    ElMessage.error(err?.data?.statusMessage || err?.message || t('users.statusFailed'));
  } finally {
    statusSavingId.value = null;
  }
};

const onDelete = async (row: UserRow) => {
  if (row.id === authStore.user?.id) {
    ElMessage.warning(t('users.cannotDeleteSelf'));
    return;
  }

  try {
    await ElMessageBox.confirm(
      t('users.deleteConfirm', { name: row.username }),
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
    await useApiFetch(`/api/users/${row.id}`, {
      method: 'DELETE',
      credentials: 'include'
    });
    ElMessage.success(t('users.deleted'));
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || t('users.deleteFailed'));
  }
};

onMounted(() => fetchData());
watch([currentPage, pageSize, searchQuery, statusFilter], () => fetchData());
usePageRefresh(() => fetchData());
</script>
