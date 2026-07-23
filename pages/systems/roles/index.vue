<template>
  <div :class="styles.pageContainer">
    <el-alert v-if="error" type="error" :title="error.message || error" show-icon :class="styles.alert" />

    <div :class="styles.premiumCard">
      <div :class="styles.toolbar">
        <div :class="styles.filterSection">
          <el-input
            v-model="searchQuery"
            placeholder="Tìm kiếm tên vai trò, mô tả..."
            :prefix-icon="Search"
            :class="styles.searchInput"
            clearable
          />
        </div>
        <el-button type="primary" :icon="Plus" @click="openCreate">Tạo vai trò mới</el-button>
      </div>

      <DataTable
        :data="apiResponse?.data || []"
        :total="apiResponse?.total || 0"
        :loading="pending"
        v-model:page-size="pageSize"
        v-model:current-page="currentPage"
        row-key="id"
      >
        <el-table-column prop="name" label="Tên vai trò" min-width="150">
          <template #default="scope">
            <span :class="styles.fwBold">{{ scope.row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="Mô tả" min-width="250">
          <template #default="scope">
            {{ scope.row.description || '-' }}
          </template>
        </el-table-column>
        <el-table-column prop="userCount" label="Số người dùng" width="150" align="center">
          <template #default="scope">
            <el-tag size="small" type="info">{{ scope.row.userCount }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="Thao tác" width="160" align="right">
          <template #default="scope">
            <el-tooltip content="Phân quyền" placement="top">
              <el-button
                type="warning"
                link
                :icon="Setting"
                @click="navigateTo(`/systems/roles/${scope.row.id}/permissions`)"
              />
            </el-tooltip>
            <el-tooltip content="Chỉnh sửa" placement="top">
              <el-button type="primary" link :icon="Edit" @click="openEdit(scope.row)" />
            </el-tooltip>
            <el-tooltip content="Xóa" placement="top">
              <el-button type="danger" link :icon="Delete" @click="onDelete(scope.row)" />
            </el-tooltip>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? 'Chỉnh sửa vai trò' : 'Tạo vai trò mới'"
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
        <el-form-item label="Tên vai trò" prop="name">
          <el-input v-model="form.name" placeholder="Admin, Editor..." />
        </el-form-item>
        <el-form-item label="Mô tả" prop="description">
          <el-input
            v-model="form.description"
            type="textarea"
            :rows="3"
            placeholder="Mô tả ngắn về vai trò"
          />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">Hủy</el-button>
        <el-button type="primary" :loading="saving" @click="onSubmit">
          {{ isEdit ? 'Lưu thay đổi' : 'Tạo vai trò' }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import styles from './roles.module.scss';
import { ref, reactive, computed, watch, onMounted } from 'vue';
import { Plus, Edit, Delete, Setting, Search } from '@element-plus/icons-vue';
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus';
import { useAuthStore } from '~/stores/auth';

interface RoleRow {
  id: string;
  name: string;
  description?: string | null;
  userCount: number;
}

const authStore = useAuthStore();
const currentPage = ref(1);
const pageSize = ref(10);
const searchQuery = ref('');

const apiResponse = ref<any>(null);
const pending = ref(false);
const error = ref<any>(null);

const dialogVisible = ref(false);
const saving = ref(false);
const formRef = ref<FormInstance>();
const editingId = ref<string | null>(null);

const form = reactive({
  name: '',
  description: ''
});

const isEdit = computed(() => !!editingId.value);

const formRules: FormRules = {
  name: [
    { required: true, message: 'Nhập tên vai trò', trigger: 'blur' },
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

    const res = await $fetch<any>('/api/roles', {
      params,
      headers: authHeaders()
    });
    apiResponse.value = res;
  } catch (err: any) {
    error.value = err;
    console.error('Fetch Roles Error:', err);
  } finally {
    pending.value = false;
  }
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
      ElMessage.success('Đã cập nhật vai trò');
    } else {
      await $fetch('/api/roles', {
        method: 'POST',
        body: {
          name: form.name.trim(),
          description: form.description.trim() || null
        },
        headers: authHeaders()
      });
      ElMessage.success('Đã tạo vai trò');
    }
    dialogVisible.value = false;
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || 'Thao tác thất bại');
  } finally {
    saving.value = false;
  }
};

const onDelete = async (row: RoleRow) => {
  if (row.userCount > 0) {
    ElMessage.warning(
      `Không thể xóa: còn ${row.userCount} người dùng đang dùng vai trò “${row.name}”`
    );
    return;
  }

  try {
    await ElMessageBox.confirm(
      `Xóa vai trò “${row.name}”? Bản ghi sẽ được ẩn (soft delete).`,
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
    await $fetch(`/api/roles/${row.id}`, {
      method: 'DELETE',
      headers: authHeaders()
    });
    ElMessage.success('Đã xóa vai trò');
    await fetchData();
  } catch (err: any) {
    ElMessage.error(err?.data?.statusMessage || err?.message || 'Không thể xóa vai trò');
  }
};

onMounted(() => fetchData());
watch([currentPage, pageSize, searchQuery], () => fetchData());
</script>
