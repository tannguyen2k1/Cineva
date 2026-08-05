<template>
  <div :class="styles.container">
    <el-table 
      :data="data" 
      class="premium-table" 
      style="width: 100%; height: 100%; flex: 1;" 
      v-bind="$attrs"
      v-loading="loading"
    >
      <slot />
    </el-table>
    
    <div :class="styles.paginationWrapper" v-if="total > 0">
      <el-pagination 
        background 
        layout="total, sizes, prev, pager, next, jumper" 
        :total="total"
        :page-size="pageSize"
        :current-page="currentPage"
        :page-sizes="[10, 20, 50, 100]"
        @current-change="handlePageChange"
        @size-change="handleSizeChange"
      />
    </div>
  </div>
</template>

<script setup lang="ts" generic="T extends Record<string, any>">
import styles from './DataTable.module.scss';

withDefaults(defineProps<{
  data: T[],
  total?: number,
  loading?: boolean,
  pageSize?: number,
  currentPage?: number
}>(), {
  total: 0,
  loading: false,
  pageSize: 10,
  currentPage: 1
});

const emit = defineEmits<{
  (e: 'update:currentPage', val: number): void;
  (e: 'update:pageSize', val: number): void;
  (e: 'page-change', val: number): void;
  (e: 'size-change', val: number): void;
}>();

const handlePageChange = (val: number) => {
  emit('update:currentPage', val);
  emit('page-change', val);
};

const handleSizeChange = (val: number) => {
  emit('update:pageSize', val);
  emit('size-change', val);
};
</script>
