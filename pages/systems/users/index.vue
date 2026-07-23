<template>
  <div :class="styles.pageContainer">
    <div :class="styles.pageHeader">
      <h2>Quản lý người dùng</h2>
      <el-button type="primary" :icon="Plus">Thêm người dùng mới</el-button>
    </div>

    <div :class="styles.premiumCard">
      <div class="filter-section">
        <el-input
          v-model="searchQuery"
          placeholder="Tìm kiếm theo username hoặc tên..."
          prefix-icon="Search"
          class="search-input"
          clearable
        />
        <el-select v-model="statusFilter" placeholder="Trạng thái" class="filter-select">
          <el-option label="Tất cả" value="" />
          <el-option label="Hoạt động" value="active" />
          <el-option label="Bị khóa" value="inactive" />
        </el-select>
      </div>

      <DataTable 
        :data="users" 
        :total="50" 
        v-model:page-size="pageSize" 
        v-model:current-page="currentPage" 
        row-key="id"
      >
        <el-table-column prop="username" label="Username" min-width="180">
          <template #default="scope">
            <div class="user-cell">
              <el-avatar size="small" :style="{ backgroundColor: getAvatarColor(scope.row.username) }">
                {{ scope.row.username.charAt(0).toUpperCase() }}
              </el-avatar>
              <span class="fw-bold">{{ scope.row.username }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="fullName" label="Họ và tên" min-width="200" />
        <el-table-column prop="role" label="Vai trò" min-width="150">
          <template #default="scope">
            <el-tag size="small" :type="scope.row.role === 'Admin' ? 'danger' : 'info'">{{ scope.row.role }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="isActive" label="Trạng thái" width="120">
          <template #default="scope">
            <el-switch v-model="scope.row.isActive" />
          </template>
        </el-table-column>
        <el-table-column label="Thao tác" width="180" align="right">
          <template #default>
            <el-button type="primary" link icon="Edit">Sửa</el-button>
            <el-button type="danger" link icon="Delete">Xóa</el-button>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import styles from './users.module.scss';
import { ref } from 'vue';
import { Search, Plus, Edit, Delete } from '@element-plus/icons-vue';

// Mock data
const searchQuery = ref('');
const statusFilter = ref('');

const users = ref([
  { id: '1', username: 'admin', fullName: 'Super Admin', role: 'Admin', isActive: true },
  { id: '2', username: 'johndoe', fullName: 'John Doe', role: 'User', isActive: true },
  { id: '3', username: 'janedoe', fullName: 'Jane Doe', role: 'User', isActive: false },
]);

const getAvatarColor = (name: string) => {
  const colors = ['#f38b6d', '#409EFF', '#67C23A', '#E6A23C', '#909399'];
  const index = name.length % colors.length;
  return colors[index];
};

const currentPage = ref(1);
const pageSize = ref(10);
</script>

<style scoped>
.page-container {
  display: flex;
  flex-direction: column;
}

.filter-section {
  display: flex;
  gap: 15px;
  margin-bottom: 24px;
}

.search-input {
  width: 320px;
}

.filter-select {
  width: 160px;
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}

.fw-bold {
  font-weight: 600;
  color: var(--text-primary);
}


</style>
