<template>
  <div :class="styles.pageContainer">
    <div :class="styles.pageHeader">
      <h2>Quản lý Tenant (Không gian làm việc)</h2>
      <el-button type="primary" :icon="Plus">Tạo Tenant mới</el-button>
    </div>

    <div :class="styles.premiumCard">
      <DataTable 
        :data="tenants" 
        :total="tenants.length"
        v-model:page-size="pageSize"
        v-model:current-page="currentPage"
      >
        <el-table-column prop="name" label="Tên Tenant" min-width="150">
          <template #default="scope">
            <span class="fw-bold">{{ scope.row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="domain" label="Domain / Slug" min-width="150">
          <template #default="scope">
            <span style="color: var(--text-secondary)">{{ scope.row.domain }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="isActive" label="Trạng thái" width="120">
          <template #default="scope">
            <el-switch v-model="scope.row.isActive" />
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="Ngày tạo" width="150" />
        <el-table-column label="Thao tác" width="150" align="right">
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
import styles from './tenants.module.scss';
import { ref } from 'vue';
import { Plus, Edit, Delete } from '@element-plus/icons-vue';

// Mock data
const tenants = ref([
  { id: '1', name: 'Default Workspace', domain: 'default', isActive: true, createdAt: '2023-10-01' },
  { id: '2', name: 'Công ty ABC', domain: 'cong-ty-abc', isActive: true, createdAt: '2023-10-15' },
  { id: '3', name: 'Công ty XYZ', domain: 'cong-ty-xyz', isActive: false, createdAt: '2023-11-02' },
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
