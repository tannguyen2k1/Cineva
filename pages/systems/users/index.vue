<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="error.message || error" show-icon :class="styles.alert" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <div :class="styles.filterSection">
          <el-input
            v-model="searchQuery"
            placeholder="Tìm kiếm username, họ tên..."
            :prefix-icon="Search"
            :class="styles.searchInput"
            clearable
          />
          <el-select v-model="statusFilter" placeholder="Trạng thái" :class="styles.filterSelect" clearable>
            <el-option label="Hoạt động" value="active" />
            <el-option label="Bị khóa" value="inactive" />
          </el-select>
        </div>
        <el-button type="primary" :icon="Plus" @click="openCreate">Thêm Người dùng</el-button>
      </div>

      <DataTable
        :data="apiResponse?.data || []"
        :total="apiResponse?.total || 0"
        :loading="pending"
        v-model:page-size="pageSize"
        v-model:current-page="currentPage"
        row-key="id"
      >
        <el-table-column prop="username" label="Username" min-width="180">
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
        <el-table-column prop="fullName" label="Họ và tên" min-width="200">
          <template #default="scope">
            {{ scope.row.fullName || '-' }}
          </template>
        </el-table-column>
        <el-table-column label="Vai trò" min-width="200">
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
        <el-table-column prop="isActive" label="Trạng thái" width="120">
          <template #default="scope">
            <el-switch
              :model-value="scope.row.isActive"
              :disabled="scope.row.id === authStore.user?.id || statusSavingId === scope.row.id"
              @change="(val: string | number | boolean) => onToggleActive(scope.row, Boolean(val))"
            />
          </template>
        </el-table-column>
        <el-table-column label="Thao tác" width="120" align="right">
          <template #default="scope">
            <el-tooltip content="Chỉnh sửa" placement="top">
              <el-button type="primary" link :icon="Edit" @click="openEdit(scope.row)" />
            </el-tooltip>
            <el-tooltip content="Xóa" placement="top">
              <el-button
                type="danger"
                link
                :icon="Delete"
                :disabled="scope.row.id === authStore.user?.id"
                @click="onDelete(scope.row)"
              />
            </el-tooltip>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? 'Chỉnh sửa người dùng' : 'Thêm người dùng'"
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
        <el-form-item label="Username" prop="username">
          <el-input
            v-model="form.username"
            placeholder="nguyenvana"
            :disabled="isEdit"
            autocomplete="off"
          />
        </el-form-item>
        <el-form-item label="Họ và tên" prop="fullName">
          <el-input v-model="form.fullName" placeholder="Nguyễn Văn A" />
        </el-form-item>
        <el-form-item label="Email" prop="email">
          <el-input v-model="form.email" placeholder="ban@congty.com" />
        </el-form-item>
        <el-form-item :label="isEdit ? 'Mật khẩu mới' : 'Mật khẩu'" prop="password">
          <el-input
            v-model="form.password"
            type="password"
            :placeholder="isEdit ? 'Để trống nếu không đổi' : '••••••••'"
            show-password
            autocomplete="new-password"
          />
        </el-form-item>
        <el-form-item label="Vai trò" prop="roleIds">
          <el-select
            v-model="form.roleIds"
            multiple
            filterable
            placeholder="Chọn vai trò"
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
        <el-form-item label="Trạng thái">
          <el-switch
            v-model="form.isActive"
            active-text="Hoạt động"
            inactive-text="Khóa"
            :disabled="isEdit && form.id === authStore.user?.id"
          />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">Hủy</el-button>
        <el-button type="primary" :loading="saving" @click="onSubmit">
          {{ isEdit ? 'Lưu thay đổi' : 'Tạo người dùng' }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import styles from './users.module.scss';
import { ref, reactive, computed, watch, onMounted } from 'vue';
import { Search, Plus, Edit, Delete } from '@element-plus/icons-vue';
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus';
import { useAuthStore } from '~/stores/auth';

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

const authStore = useAuthStore();
const searchQuery = ref('');
const statusFilter = ref('');
const currentPage = ref(1);
const pageSize = ref(10);

const apiResponse = ref<any>(null);
const pending = ref(false);
const error = ref<any>(null);

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
    { required: true, message: 'Nhập username', trigger: 'blur' },
    { min: 3, message: 'Ít nhất 3 ký tự', trigger: 'blur' }
  ],
  email: [
    { type: 'email', message: 'Email không hợp lệ', trigger: ['blur', 'change'] }
  ],
  password: isEdit.value
    ? [
        {
          validator: (_rule, value, callback) => {
            if (value && value.length < 6) callback(new Error('Mật khẩu phải có ít nhất 6 ký tự'));
            else callback();
          },
          trigger: 'blur'
        }
      ]
    : [
        { required: true, message: 'Nhập mật khẩu', trigger: 'blur' },
        { min: 6, message: 'Mật khẩu phải có ít nhất 6 ký tự', trigger: 'blur' }
      ]
}));

const roleOptions = ref<RoleOption[]>([]);
const rolesLoading = ref(false);

const authHeaders = () => {
  const headers: Record<string, string> = {};
  if (authStore.token) headers.Authorization = `Bearer ${authStore.token}`;
  if (authStore.tenant_id) headers['x-tenant-id'] = authStore.tenant_id;
  return headers;
};

const fetchData = async () => {
  pending.value = true;
  error.value = null;
  try {
    const params: Record<string, any> = {
      page: currentPage.value,
      pageSize: pageSize.value
    };
    if (searchQuery.value) params.search = searchQuery.value;
    if (statusFilter.value) params.status = statusFilter.value;

    const res = await $fetch<any>('/api/users', {
      params,
      headers: authHeaders()
    });
    apiResponse.value = res;
  } catch (err: any) {
    error.value = err;
    console.error('Fetch Users Error:', err);
  } finally {
    pending.value = false;
  }
};

const fetchRoles = async () => {
  rolesLoading.value = true;
  try {
    const res = await $fetch<any>('/api/roles', {
      params: { page: 1, pageSize: 100 },
      headers: authHeaders()
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

      await $fetch(`/api/users/${editingId.value}`, {
        method: 'PUT',
        body: payload,
        headers: authHeaders()
      });
      ElMessage.success('Đã cập nhật người dùng');
    } else {
      await $fetch('/api/users', {
        method: 'POST',
        body: {
          username: form.username.trim(),
          password: form.password,
          fullName: form.fullName || null,
          email: form.email || null,
          isActive: form.isActive,
          roleIds: form.roleIds
        },
        headers: authHeaders()
      });
      ElMessage.success('Đã tạo người dùng');
    }
    dialogVisible.value = false;
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || 'Thao tác thất bại');
  } finally {
    saving.value = false;
  }
};

const onToggleActive = async (row: UserRow, next: boolean) => {
  if (row.id === authStore.user?.id) {
    ElMessage.warning('Không thể khóa tài khoản đang đăng nhập');
    return;
  }

  statusSavingId.value = row.id;
  const prev = row.isActive;
  row.isActive = next;
  try {
    await $fetch(`/api/users/${row.id}`, {
      method: 'PUT',
      body: { isActive: next },
      headers: authHeaders()
    });
    ElMessage.success(next ? 'Đã mở khóa người dùng' : 'Đã khóa người dùng');
  } catch (err: any) {
    row.isActive = prev;
    ElMessage.error(err?.data?.statusMessage || err?.message || 'Không thể cập nhật trạng thái');
  } finally {
    statusSavingId.value = null;
  }
};

const onDelete = async (row: UserRow) => {
  if (row.id === authStore.user?.id) {
    ElMessage.warning('Không thể xóa tài khoản đang đăng nhập');
    return;
  }

  try {
    await ElMessageBox.confirm(
      `Xóa người dùng “${row.username}”? Bản ghi sẽ được ẩn (soft delete), không xóa cứng khỏi hệ thống.`,
      'Xác nhận xóa',
      {
        type: 'warning',
        confirmButtonText: 'Xóa',
        cancelButtonText: 'Hủy'
      }
    );
  } catch {
    return;
  }

  try {
    await $fetch(`/api/users/${row.id}`, {
      method: 'DELETE',
      headers: authHeaders()
    });
    ElMessage.success('Đã xóa người dùng');
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || 'Không thể xóa người dùng');
  }
};

onMounted(() => fetchData());
watch([currentPage, pageSize, searchQuery, statusFilter], () => fetchData());
</script>
