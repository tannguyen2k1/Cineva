<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="error.message || error" show-icon :class="styles.alert" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <div :class="styles.filterSection">
          <el-input
            v-model="searchQuery"
            placeholder="Tìm kiếm tên tenant, domain..."
            :prefix-icon="Search"
            :class="styles.searchInput"
            clearable
          />
          <el-select v-model="statusFilter" placeholder="Trạng thái" :class="styles.filterSelect" clearable>
            <el-option label="Hoạt động" value="active" />
            <el-option label="Bị khóa" value="inactive" />
          </el-select>
        </div>
        <el-button type="primary" :icon="Plus" @click="openCreate">Tạo Tenant mới</el-button>
      </div>

      <DataTable
        :data="apiResponse?.data || []"
        :total="apiResponse?.total || 0"
        :loading="pending"
        v-model:page-size="pageSize"
        v-model:current-page="currentPage"
        row-key="id"
      >
        <el-table-column prop="name" label="Tên Tenant (Không gian làm việc)" min-width="250">
          <template #default="scope">
            <span :class="styles.fwBold">{{ scope.row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="domain" label="Domain / Slug" min-width="150">
          <template #default="scope">
            <span style="color: var(--text-secondary)">{{ scope.row.domain || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="userCount" label="Số lượng User" width="150" align="center">
          <template #default="scope">
            <el-tag size="small" type="info">{{ scope.row.userCount }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="isActive" label="Trạng thái" width="120">
          <template #default="scope">
            <el-switch
              :model-value="scope.row.isActive"
              :disabled="scope.row.id === authStore.tenant_id || statusSavingId === scope.row.id"
              @change="(val: string | number | boolean) => onToggleActive(scope.row, Boolean(val))"
            />
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="Ngày tạo" width="150">
          <template #default="scope">
            <span style="color: var(--text-secondary)">
              {{ new Date(scope.row.createdAt).toLocaleDateString('vi-VN') }}
            </span>
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
                :disabled="scope.row.id === authStore.tenant_id"
                @click="onDelete(scope.row)"
              />
            </el-tooltip>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? 'Chỉnh sửa tenant' : 'Tạo tenant mới'"
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
        <el-form-item label="Tên workspace" prop="name">
          <el-input v-model="form.name" placeholder="default, acme..." />
        </el-form-item>
        <el-form-item label="Domain / Slug" prop="domain">
          <el-input v-model="form.domain" placeholder="acme.local (tuỳ chọn)" />
        </el-form-item>
        <el-form-item label="Trạng thái">
          <el-switch
            v-model="form.isActive"
            active-text="Hoạt động"
            inactive-text="Khóa"
            :disabled="isEdit && form.id === authStore.tenant_id"
          />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">Hủy</el-button>
        <el-button type="primary" :loading="saving" @click="onSubmit">
          {{ isEdit ? 'Lưu thay đổi' : 'Tạo tenant' }}
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

interface TenantRow {
  id: string;
  name: string;
  domain?: string | null;
  isActive: boolean;
  userCount: number;
  createdAt: string;
}

const authStore = useAuthStore();
const currentPage = ref(1);
const pageSize = ref(10);
const searchQuery = ref('');
const statusFilter = ref('');

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

const formRules: FormRules = {
  name: [
    { required: true, message: 'Nhập tên workspace', trigger: 'blur' },
    { min: 2, message: 'Ít nhất 2 ký tự', trigger: 'blur' }
  ]
};

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

    const res = await $fetch<any>('/api/tenants', {
      params,
      headers: authHeaders()
    });
    apiResponse.value = res;
  } catch (err: any) {
    error.value = err;
    console.error('Fetch Tenants Error:', err);
  } finally {
    pending.value = false;
  }
};

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
      ElMessage.success('Đã cập nhật tenant');
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
          ? `Đã tạo tenant — đăng nhập: ${creds.username} / ${creds.password}`
          : 'Đã tạo tenant'
      );
    }
    dialogVisible.value = false;
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || 'Thao tác thất bại');
  } finally {
    saving.value = false;
  }
};

const onToggleActive = async (row: TenantRow, next: boolean) => {
  if (row.id === authStore.tenant_id) {
    ElMessage.warning('Không thể khóa tenant đang đăng nhập');
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
    ElMessage.success(next ? 'Đã mở khóa tenant' : 'Đã khóa tenant');
  } catch (err: any) {
    row.isActive = prev;
    ElMessage.error(err?.data?.statusMessage || err?.message || 'Không thể cập nhật trạng thái');
  } finally {
    statusSavingId.value = null;
  }
};

const onDelete = async (row: TenantRow) => {
  if (row.id === authStore.tenant_id) {
    ElMessage.warning('Không thể xóa tenant đang đăng nhập');
    return;
  }

  if (row.userCount > 0) {
    ElMessage.warning(
      `Không thể xóa: còn ${row.userCount} người dùng trong tenant “${row.name}”`
    );
    return;
  }

  try {
    await ElMessageBox.confirm(
      `Xóa tenant “${row.name}”? Bản ghi sẽ được ẩn (soft delete).`,
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
    await $fetch(`/api/tenants/${row.id}`, {
      method: 'DELETE',
      headers: authHeaders()
    });
    ElMessage.success('Đã xóa tenant');
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || 'Không thể xóa tenant');
  }
};

onMounted(() => fetchData());
watch([currentPage, pageSize, searchQuery, statusFilter], () => fetchData());
</script>
