<template>
  <el-aside width="260px" :class="styles.aside">
    <div :class="styles.logo">
      <div :class="styles.logoMark" aria-hidden="true" />
      <div :class="styles.logoText">
        <h3>{{ t('app.name') }}</h3>
        <p :class="styles.logoHint">{{ t('app.tagline') }}</p>
      </div>
    </div>

    <nav :class="styles.nav">
      <el-menu
        :key="activeMenu"
        :default-active="activeMenu"
        :class="styles.menu"
        style="--el-menu-bg-color: transparent; --el-menu-text-color: var(--text-sidebar); --el-menu-active-color: var(--text-sidebar-active);"
        router
      >
        <div :class="styles.menuLabel">{{ t('nav.overview') }}</div>

        <el-menu-item
          v-if="authStore.hasPermission('read:dashboard')"
          index="/dashboard"
        >
          <el-icon><Odometer /></el-icon>
          <span>{{ t('nav.dashboard') }}</span>
        </el-menu-item>

        <div :class="styles.menuLabel">{{ t('nav.content') }}</div>

        <el-menu-item
          v-if="authStore.hasPermission('read:sync')"
          index="/films/sync"
        >
          <el-icon><Refresh /></el-icon>
          <span>{{ t('nav.sync') }}</span>
        </el-menu-item>

        <el-menu-item
          v-if="authStore.hasPermission('read:films')"
          index="/films"
        >
          <el-icon><Film /></el-icon>
          <span>{{ t('nav.adminFilms') }}</span>
        </el-menu-item>

        <el-menu-item
          v-if="authStore.hasPermission('read:banners')"
          index="/films/banners"
        >
          <el-icon><Picture /></el-icon>
          <span>{{ t('nav.banners') }}</span>
        </el-menu-item>

        <el-menu-item
          v-if="authStore.hasPermission('read:featured')"
          index="/films/featured"
        >
          <el-icon><Star /></el-icon>
          <span>{{ t('nav.featured') }}</span>
        </el-menu-item>

        <el-menu-item
          v-if="authStore.hasPermission('read:comments')"
          index="/films/comments"
        >
          <el-icon><ChatDotRound /></el-icon>
          <span>{{ t('nav.commentsAdmin') }}</span>
        </el-menu-item>

        <div :class="styles.menuLabel">{{ t('nav.system') }}</div>

        <el-menu-item
          v-if="authStore.hasPermission('read:users')"
          index="/systems/users"
        >
          <el-icon><User /></el-icon>
          <span>{{ t('nav.users') }}</span>
        </el-menu-item>

        <el-menu-item
          v-if="authStore.hasPermission('read:roles')"
          index="/systems/roles"
        >
          <el-icon><Box /></el-icon>
          <span>{{ t('nav.roles') }}</span>
        </el-menu-item>

        <el-menu-item
          v-if="authStore.hasPermission('read:logs')"
          index="/systems/logs"
        >
          <el-icon><Document /></el-icon>
          <span>{{ t('nav.logs') }}</span>
        </el-menu-item>
      </el-menu>
    </nav>

    <div :class="styles.sidebarFooter">
      <span :class="styles.sidebarBrand">{{ t('app.name') }}</span>
      <span :class="styles.sidebarVersion">v1.0</span>
    </div>
  </el-aside>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import {
  Odometer,
  User,
  Box,
  Document,
  Refresh,
  Film,
  Picture,
  Star,
  ChatDotRound
} from '@element-plus/icons-vue';
import styles from './DesktopSidebar.module.scss';

const { t } = useI18n();
const route = useRoute();
const authStore = useAuthStore();

const activeMenu = computed(() => {
  if (route.path === '/films' || route.path.startsWith('/films?')) return '/films';
  if (route.path.startsWith('/films/sync')) return '/films/sync';
  if (route.path.startsWith('/films/banners')) return '/films/banners';
  if (route.path.startsWith('/films/featured')) return '/films/featured';
  if (route.path.startsWith('/films/comments')) return '/films/comments';
  if (route.path.startsWith('/systems/roles')) return '/systems/roles';
  if (route.path.startsWith('/systems/users')) return '/systems/users';
  if (route.path.startsWith('/systems/logs')) return '/systems/logs';
  if (route.path.startsWith('/profile')) return '/profile';
  if (route.path.startsWith('/settings')) return '/settings';
  if (route.path.startsWith('/dashboard')) return '/dashboard';
  return route.path;
});
</script>
