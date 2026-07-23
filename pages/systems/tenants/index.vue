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
        <el-button type="primary" :icon="Plus">Tạo Tenant mới</el-button>
      </div>

      <DataTable 
        :data="apiResponse?.data || []" 
        :total="apiResponse?.total || 0"
        :loading="pending"
        v-model:page-size="pageSize"
        v-model:current-page="currentPage"
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
            <el-switch v-model="scope.row.isActive" />
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="Ngày tạo" width="150">
          <template #default="scope">
            <span style="color: var(--text-secondary)">{{ new Date(scope.row.createdAt).toLocaleDateString('vi-VN') }}</span>
          </template>
        </el-table-column>
        <el-table-column label="Thao tác" width="120" align="right">
          <template #default>
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
import styles from './tenants.module.scss';
import { ref, watch, onMounted } from 'vue';
import { Plus, Edit, Delete, Search } from '@element-plus/icons-vue';
import { useAuthStore } from '~/stores/auth';

const authStore = useAuthStore();
const currentPage = ref(1);
const pageSize = ref(10);
const searchQuery = ref('');
const statusFilter = ref('');

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
    if (statusFilter.value) params.status = statusFilter.value;
    
    const headers: any = {};
    if (authStore.token) headers.Authorization = `Bearer ${authStore.token}`;
    if (authStore.tenant_id) headers['x-tenant-id'] = authStore.tenant_id;
    
    const res = await $fetch<any>('/api/tenants', { params, headers });
    apiResponse.value = res;
  } catch (err: any) {
    error.value = err;
    console.error('Fetch Tenants Error:', err);
  } finally {
    pending.value = false;
  }
};

onMounted(() => fetchData());
watch([currentPage, pageSize, searchQuery, statusFilter], () => fetchData());

</script>
