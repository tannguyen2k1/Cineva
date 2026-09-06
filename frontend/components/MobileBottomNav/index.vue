<template>
  <nav :class="styles.bottomNav" aria-label="Điều hướng admin">
    <NuxtLink
      v-if="authStore.hasPermission('read:dashboard')"
      to="/dashboard"
      :class="[styles.navItem, isActive('/dashboard') && styles.active]"
    >
      <el-icon :class="styles.icon"><Odometer /></el-icon>
      <span :class="styles.label">{{ t('nav.dashboard') }}</span>
    </NuxtLink>

    <NuxtLink
      v-if="authStore.hasPermission('read:films')"
      to="/films"
      :class="[styles.navItem, isFilmsActive && styles.active]"
    >
      <el-icon :class="styles.icon"><Film /></el-icon>
      <span :class="styles.label">{{ t('nav.adminFilms') }}</span>
    </NuxtLink>

    <NuxtLink
      v-if="authStore.hasPermission('read:sync')"
      to="/films/sync"
      :class="[styles.navItem, isActive('/films/sync') && styles.active]"
    >
      <el-icon :class="styles.icon"><Refresh /></el-icon>
      <span :class="styles.label">{{ t('nav.sync') }}</span>
    </NuxtLink>

    <NuxtLink
      v-if="authStore.hasPermission('read:users')"
      to="/systems/users"
      :class="[styles.navItem, isActive('/systems/users') && styles.active]"
    >
      <el-icon :class="styles.icon"><UserFilled /></el-icon>
      <span :class="styles.label">{{ t('nav.users') }}</span>
    </NuxtLink>

    <button
      type="button"
      :class="[styles.navItem, isDrawerOpen && styles.active]"
      @click="isDrawerOpen = true"
    >
      <el-icon :class="styles.icon"><MoreFilled /></el-icon>
      <span :class="styles.label">{{ t('nav.menu') }}</span>
    </button>

    <MobileMenuDrawer v-model="isDrawerOpen" />
  </nav>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import {
  Odometer,
  Film,
  Refresh,
  UserFilled,
  MoreFilled
} from '@element-plus/icons-vue'
import styles from './MobileBottomNav.module.scss'

const route = useRoute()
const { t } = useI18n()
const authStore = useAuthStore()

const isDrawerOpen = ref(false)

const isFilmsActive = computed(() => {
  return route.path === '/films'
})

function isActive(path: string) {
  return route.path === path || route.path.startsWith(`${path}/`)
}

watch(
  () => route.fullPath,
  () => {
    isDrawerOpen.value = false
  }
)
</script>
