<template>
  <nav :class="styles.bottomNav" aria-label="Điều hướng mobile">
    <NuxtLink
      to="/"
      :class="[styles.navItem, isActiveExact('/') && styles.active]"
    >
      <el-icon :class="styles.icon"><HomeFilled /></el-icon>
      <span :class="styles.label">{{ t('cineva.home') }}</span>
    </NuxtLink>

    <NuxtLink
      to="/phim"
      :class="[styles.navItem, isActive('/phim') && styles.active]"
    >
      <el-icon :class="styles.icon"><Film /></el-icon>
      <span :class="styles.label">{{ t('cineva.movies') }}</span>
    </NuxtLink>

    <NuxtLink
      :to="authStore.isLoggedIn ? '/tu-phim' : '/login'"
      :class="[styles.navItem, isActive('/tu-phim') && styles.active]"
    >
      <el-icon :class="styles.icon"><StarFilled /></el-icon>
      <span :class="styles.label">{{ t('cineva.watchlistShort') }}</span>
    </NuxtLink>

    <NuxtLink
      :to="authStore.isLoggedIn ? '/da-xem' : '/login'"
      :class="[styles.navItem, isActive('/da-xem') && styles.active]"
    >
      <el-icon :class="styles.icon"><Clock /></el-icon>
      <span :class="styles.label">{{ t('cineva.watchedShort') }}</span>
    </NuxtLink>

    <button
      type="button"
      :class="[styles.navItem, menuOpen && styles.active]"
      @click="menuOpen = true"
    >
      <el-icon :class="styles.icon"><MoreFilled /></el-icon>
      <span :class="styles.label">{{ t('nav.menu') }}</span>
    </button>

    <PublicMobileMoreMenu
      v-model="menuOpen"
      :genres="genres"
      :countries="countries"
    />
  </nav>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { HomeFilled, Film, StarFilled, Clock, MoreFilled } from '@element-plus/icons-vue'
import styles from './PublicMobileBottomNav.module.scss'

defineProps<{
  genres?: { slug: string; name: string }[]
  countries?: { slug: string; name: string }[]
}>()

const { t } = useI18n()
const route = useRoute()
const authStore = useAuthStore()
const menuOpen = ref(false)

function isActiveExact(path: string) {
  return route.path === path
}

function isActive(path: string) {
  return route.path === path || route.path.startsWith(`${path}/`)
}

watch(
  () => route.fullPath,
  () => {
    menuOpen.value = false
  }
)
</script>
