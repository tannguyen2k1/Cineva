<template>
  <div :class="styles.pageContainer">
    <div :class="styles.pageHeader">
      <h2>Quản lý vai trò (Roles)</h2>
      <el-button type="primary" :icon="Plus">Tạo vai trò mới</el-button>
    </div>

    <el-alert v-if="error" type="error" :title="error.message || error" show-icon style="margin-bottom: 20px" />

    <div :class="styles.premiumCard">
      <DataTable 
        :data="apiResponse?.data || []" 
        :total="apiResponse?.total || 0"
        :loading="pending"
        v-model:page-size="pageSize"
        v-model:current-page="currentPage"
      >
        <el-table-column prop="name" label="Tên vai trò" min-width="150">
          <template #default="scope">
            <span :class="styles.fwBold">{{ scope.row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="Mô tả" min-width="250" />
        <el-table-column prop="userCount" label="Số người dùng" width="150" align="center">
          <template #default="scope">
            <el-tag size="small" type="info">{{ scope.row.userCount }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="Thao tác" width="160" align="right">
          <template #default>
            <el-tooltip content="Phân quyền" placement="top">
              <el-button type="warning" link :icon="Setting" />
            </el-tooltip>
            <el-tooltip content="Chỉnh sửa" placement="top">
              <el-button type="primary" link :icon="Edit" />
            </el-tooltip>
            <el-tooltip content="Xóa" placement="top">
              <el-button type="danger" link :icon="Delete" />
            </el-tooltip>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import styles from './roles.module.scss';
import { ref, watch, onMounted } from 'vue';
import { Plus, Edit, Delete, Setting } from '@element-plus/icons-vue';
import { useAuthStore } from '~/stores/auth';

const authStore = useAuthStore();
const currentPage = ref(1);
const pageSize = ref(10);
const searchQuery = ref('');

const apiResponse = ref<any>(null);
const pending = ref(false);
const error = ref<any>(null);

const fetchData = async () => {
  pending.value = true;
  error.value = null;
  try {
    const params: Record<string, any> = {
      page: currentPage.value,
      pageSize: pageSize.value,
    };
    if (searchQuery.value) params.search = searchQuery.value;
    
    const headers: any = {};
    if (authStore.token) headers.Authorization = `Bearer ${authStore.token}`;
    if (authStore.tenant_id) headers['x-tenant-id'] = authStore.tenant_id;
    
    const res = await $fetch<any>('/api/roles', { params, headers });
    apiResponse.value = res;
  } catch (err: any) {
    error.value = err;
    console.error('Fetch Roles Error:', err);
  } finally {
    pending.value = false;
  }
};

onMounted(() => fetchData());
watch([currentPage, pageSize, searchQuery], () => fetchData());

</script>
