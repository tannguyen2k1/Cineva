<template>
  <el-container :class="styles.layoutContainer">
    <DesktopSidebar />

    <el-container :class="styles.mainWrapper">
      <el-header :class="styles.header">
        <div :class="styles.headerLeft">
          <h1 :class="styles.pageTitle">{{ pageTitle }}</h1>
        </div>

        <div :class="styles.headerRight">
          <div :class="styles.desktopOnly">
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

      <el-main :class="styles.mainShell">
        <div ref="mainContentRef" id="app-scroll" :class="styles.mainContent">
          <div
            data-ptr-indicator
            :class="styles.ptrIndicator"
            :style="{ height: `${maxPull}px`, transform: `translate3d(0, ${-maxPull}px, 0)` }"
          >
            <el-icon :class="[styles.ptrIcon, status === 'ready' ? styles.ptrReady : '']">
              <Loading v-if="status === 'refreshing'" class="is-loading" />
              <Bottom v-else />
            </el-icon>
            <span v-if="label" :class="styles.ptrText">{{ label }}</span>
          </div>
          <slot />
        </div>
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
import { computed, ref, provide } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useRoute, useRouter } from 'vue-router';
import {
  User,
  ArrowDown,
  SwitchButton,
  Bottom,
  Loading
} from '@element-plus/icons-vue';
import styles from './default.module.scss';

const { t } = useI18n();
const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const mainContentRef = ref<HTMLElement | null>(null);

const pageRefreshApi = providePageRefresh();
provide('appScrollEl', mainContentRef);

const ptrTexts = computed(() => ({
  pullText: t('common.pullToRefresh'),
  releaseText: t('common.refresh'),
  refreshingText: t('common.loading')
}));

const { status, label, maxPull } = usePullToRefresh(mainContentRef, ptrTexts, pageRefreshApi);

const pageTitleKeys: Record<string, string> = {
  '/dashboard': 'pages.dashboard',
  '/profile': 'pages.profile',
  '/settings': 'nav.settings',
  '/films': 'pages.adminFilms',
  '/films/sync': 'pages.sync',
  '/films/banners': 'pages.banners',
  '/films/featured': 'pages.featured',
  '/films/comments': 'pages.commentsAdmin',
  '/systems/users': 'pages.users',
  '/systems/roles': 'pages.roles',
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
