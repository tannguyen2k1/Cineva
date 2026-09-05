<template>
  <el-config-provider :locale="vi" :message="messageConfig">
    <NuxtLoadingIndicator color="#3b82f6" :height="3" />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </el-config-provider>
</template>

<script setup lang="ts">
import vi from 'element-plus/es/locale/lang/vi'

const messageConfig = {
  placement: 'top-right' as const
}
</script>
