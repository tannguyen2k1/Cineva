<template>
  <el-config-provider>
    <NuxtLoadingIndicator color="#f38b6d" :height="3" />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </el-config-provider>
</template>

<script setup lang="ts">
// Bọc toàn bộ app bằng config provider của Element Plus (VD: setup ngôn ngữ, size...)
</script>

<style>
body {
  margin: 0;
  font-family: 'Helvetica Neue', Helvetica, 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', Arial, sans-serif;
  background-color: #f5f7fa;
}
</style>
