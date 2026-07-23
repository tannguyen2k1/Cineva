<template>
  <el-config-provider :message="messageConfig">
    <NuxtLoadingIndicator color="#3b82f6" :height="3" />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </el-config-provider>
</template>

<script setup lang="ts">
const messageConfig = {
  placement: 'top-right' as const
}
</script>
