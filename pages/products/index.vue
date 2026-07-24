<template>
  <div class="demo-page">
    <el-result
      icon="success"
      title="Thông báo"
      sub-title="Bạn không có thông báo nào mới."
    >
      <template #extra>
        <el-button type="primary" @click="goBack">Về trang chủ</el-button>
      </template>
    </el-result>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';

const router = useRouter();
const goBack = () => router.push('/');
</script>

<style scoped>
.demo-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: calc(100vh - 120px);
  background-color: var(--bg-body, #f3f4f6);
}
</style>
