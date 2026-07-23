<template>
  <el-container :class="styles.layoutContainer">
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
          :key="`${activeMenu}-${locale}`"
          :default-active="activeMenu"
          :class="styles.menu"
          style="--el-menu-bg-color: transparent; --el-menu-text-color: var(--text-sidebar); --el-menu-active-color: var(--text-sidebar-active);"
          router
        >
          <div :class="styles.menuLabel">{{ t('nav.overview') }}</div>

          <el-menu-item
            v-if="authStore.hasPermission('read:dashboard')"
            index="/"
          >
            <el-icon><Odometer /></el-icon>
            <span>{{ t('nav.dashboard') }}</span>
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
            v-if="authStore.hasPermission('read:tenants')"
            index="/systems/tenants"
          >
            <el-icon><House /></el-icon>
            <span>{{ t('nav.tenants') }}</span>
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

    <el-container :class="styles.mainWrapper">
      <el-header :class="styles.header">
        <div :class="styles.headerLeft">
          <h1 :class="styles.pageTitle">{{ pageTitle }}</h1>
        </div>

        <div :class="styles.headerRight">
          <LocaleSwitcher />
          <ThemeSwitcher />

          <el-dropdown trigger="click" @command="handleCommand">
            <button type="button" :class="styles.userTrigger">
              <UserProfile
                :username="authStore.user?.username || ''"
                :full-name="authStore.user?.fullName"
                :avatar="authStore.user?.avatar"
                :size="36"
              />
              <el-icon :class="styles.userChevron"><ArrowDown /></el-icon>
            </button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="profile">
                  <el-icon><User /></el-icon>{{ t('header.profile') }}
                </el-dropdown-item>
                <el-dropdown-item divided command="logout">
                  <el-icon><SwitchButton /></el-icon>{{ t('header.logout') }}
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <el-main :class="styles.mainContent">
        <slot />
      </el-main>

      <el-footer :class="styles.footer">
        {{ t('app.footer', { year: new Date().getFullYear() }) }}
      </el-footer>
    </el-container>
  </el-container>

  <ChatWidget />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useRoute, useRouter } from 'vue-router';
import {
  User,
  Box,
  House,
  Document,
  Odometer,
  ArrowDown,
  SwitchButton
} from '@element-plus/icons-vue';
import styles from './default.module.scss';

const { t, locale } = useI18n();
const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const pageTitleKeys: Record<string, string> = {
  '/': 'pages.dashboard',
  '/profile': 'pages.profile',
  '/systems/users': 'pages.users',
  '/systems/roles': 'pages.roles',
  '/systems/tenants': 'pages.tenants',
  '/systems/logs': 'pages.logs'
};

const activeMenu = computed(() => {
  if (route.path.startsWith('/systems/roles')) return '/systems/roles';
  if (route.path.startsWith('/systems/users')) return '/systems/users';
  if (route.path.startsWith('/systems/tenants')) return '/systems/tenants';
  if (route.path.startsWith('/systems/logs')) return '/systems/logs';
  if (route.path.startsWith('/profile')) return '/profile';
  return route.path;
});

const pageTitle = computed(() => {
  if (/^\/systems\/roles\/[^/]+\/permissions$/.test(route.path)) {
    return t('pages.rolePermissions');
  }
  const key = pageTitleKeys[route.path];
  return key ? t(key) : route.path.split('/').filter(Boolean).pop() || t('app.name');
});

const handleCommand = async (command: string) => {
  if (command === 'logout') {
    authStore.logout();
    await router.push('/login');
    return;
  }
  if (command === 'profile') {
    await router.push('/profile');
  }
};
</script>
