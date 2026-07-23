<template>
  <div :class="styles.pageContainer">
    <div :class="styles.pageHeader">
      <h2>Quản lý Người dùng</h2>
      <el-button type="primary" :icon="Plus">Thêm Người dùng</el-button>
    </div>

    <el-alert v-if="error" type="error" :title="error.message || error" show-icon style="margin-bottom: 20px" />

    <div :class="styles.premiumCard">
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
              <el-avatar v-if="scope.row.avatar" size="small" :src="scope.row.avatar" />
              <el-avatar v-else size="small" :style="{ backgroundColor: getAvatarColor(scope.row.username) }">
                {{ scope.row.username.charAt(0).toUpperCase() }}
              </el-avatar>
              <span :class="styles.fwBold">{{ scope.row.username }}</span>
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
            <el-switch v-model="scope.row.isActive" />
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
import styles from './users.module.scss';
import { ref, watch, onMounted } from 'vue';
import { Search, Plus, Edit, Delete } from '@element-plus/icons-vue';
import { useAuthStore } from '~/stores/auth';

const authStore = useAuthStore();
const searchQuery = ref('');
const statusFilter = ref('');
const currentPage = ref(1);
const pageSize = ref(10);

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
    
    const res = await $fetch<any>('/api/users', { params, headers });
    apiResponse.value = res;
  } catch (err: any) {
    error.value = err;
    console.error('Fetch Users Error:', err);
  } finally {
    pending.value = false;
  }
};

onMounted(() => fetchData());
watch([currentPage, pageSize, searchQuery, statusFilter], () => fetchData());

const getAvatarColor = (name: string) => {
  const colors = ['#f38b6d', '#409EFF', '#67C23A', '#E6A23C', '#909399'];
  const index = name.length % colors.length;
  return colors[index];
};
</script>
