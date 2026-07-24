<template>
  <div class="demo-page">
    <el-result
      icon="info"
      title="Tin nhắn"
      sub-title="Tính năng đang được phát triển"
    >
      <template #extra>
        <el-button type="primary" @click="goBack">Quay lại</el-button>
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
