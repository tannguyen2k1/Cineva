<template>
  <nav :class="styles.bottomNav" aria-label="Điều hướng mobile">
    <NuxtLink
      to="/"
      :class="[styles.tab, isActiveExact('/') && styles.active]"
    >
      <el-icon :class="styles.icon"><HomeFilled /></el-icon>
      <span>{{ t('cineva.home') }}</span>
    </NuxtLink>

    <NuxtLink
      to="/phim"
      :class="[styles.tab, isActive('/phim') && styles.active]"
    >
      <el-icon :class="styles.icon"><Film /></el-icon>
      <span>{{ t('cineva.movies') }}</span>
    </NuxtLink>

    <NuxtLink
      :to="authStore.isLoggedIn ? '/tu-phim' : '/login'"
      :class="[styles.tab, isActive('/tu-phim') && styles.active]"
    >
      <el-icon :class="styles.icon"><StarFilled /></el-icon>
      <span>{{ t('cineva.watchlistShort') }}</span>
    </NuxtLink>

    <NuxtLink
      :to="authStore.isLoggedIn ? '/da-xem' : '/login'"
      :class="[styles.tab, isActive('/da-xem') && styles.active]"
    >
      <el-icon :class="styles.icon"><Clock /></el-icon>
      <span>{{ t('cineva.watchedShort') }}</span>
    </NuxtLink>

    <button
      type="button"
      :class="[styles.tab, menuOpen && styles.active]"
      @click="menuOpen = true"
    >
      <el-icon :class="styles.icon"><MoreFilled /></el-icon>
      <span>{{ t('nav.menu') }}</span>
    </button>

    <PublicMobileMoreMenu
      v-model="menuOpen"
      :genres="genres"
      :countries="countries"
    />
  </nav>
  <div :class="styles.bottomSpacer" aria-hidden="true" />
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
