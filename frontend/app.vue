<template>
  <el-config-provider :locale="elementLocale" :message="messageConfig">
    <NuxtLoadingIndicator color="#3b82f6" :height="3" />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </el-config-provider>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import vi from 'element-plus/es/locale/lang/vi'
import en from 'element-plus/es/locale/lang/en'

const { locale } = useI18n()

const messageConfig = {
  placement: 'top-right' as const
}

const elementLocale = computed(() => (locale.value === 'en' ? en : vi))
</script>
