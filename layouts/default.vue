<template>
  <el-container :class="styles.layoutContainer">
    <DesktopSidebar />

    <el-container :class="styles.mainWrapper">
      <el-header :class="styles.header">
        <div :class="styles.headerLeft">
          <h1 :class="styles.pageTitle">{{ pageTitle }}</h1>
        </div>

        <div :class="styles.headerRight">
          <LocaleSwitcher />
          
          <div :class="styles.desktopOnly">
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

  <MobileBottomNav />
  <ChatWidget />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useRoute, useRouter } from 'vue-router';
import {
  User,
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
  '/settings': 'nav.settings',
  '/systems/users': 'pages.users',
  '/systems/roles': 'pages.roles',
  '/systems/tenants': 'pages.tenants',
  '/systems/logs': 'pages.logs'
};



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
