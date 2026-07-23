<template>
  <div :class="styles.pageContainer">
    <div :class="styles.pageHeader">
      <h2>Quản lý vai trò (Roles)</h2>
      <el-button type="primary" :icon="Plus">Tạo vai trò mới</el-button>
    </div>

    <div :class="styles.premiumCard">
      <DataTable 
        :data="roles" 
        :total="roles.length"
        v-model:page-size="pageSize"
        v-model:current-page="currentPage"
      >
        <el-table-column prop="name" label="Tên vai trò" min-width="150">
          <template #default="scope">
            <span class="fw-bold">{{ scope.row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="Mô tả" min-width="250" />
        <el-table-column prop="usersCount" label="Số người dùng" width="150" align="center">
          <template #default="scope">
            <el-tag size="small" type="info">{{ scope.row.usersCount }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="Thao tác" width="200" align="right">
          <template #default>
            <el-button type="warning" link icon="Setting">Phân quyền</el-button>
            <el-button type="primary" link icon="Edit">Sửa</el-button>
            <el-button type="danger" link icon="Delete">Xóa</el-button>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import styles from './roles.module.scss';
import { ref } from 'vue';
import { Plus, Edit, Delete, Setting } from '@element-plus/icons-vue';

// Mock data
const roles = ref([
  { id: '1', name: 'Admin', description: 'Quản trị viên toàn quyền hệ thống', usersCount: 2 },
  { id: '2', name: 'Editor', description: 'Người chỉnh sửa nội dung', usersCount: 5 },
  { id: '3', name: 'Viewer', description: 'Chỉ xem dữ liệu, không có quyền sửa', usersCount: 12 },
]);

const currentPage = ref(1);
const pageSize = ref(10);
</script>

<style scoped>
.page-container {
  display: flex;
  flex-direction: column;
}

.fw-bold {
  font-weight: 600;
  color: var(--text-primary);
}
</style>
