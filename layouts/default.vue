<template>
  <el-container :class="styles.layoutContainer">
    <el-aside width="260px" :class="styles.aside">
      <div :class="styles.logo">
        <div :class="styles.logoMark" aria-hidden="true" />
        <div :class="styles.logoText">
          <h3>Admin Pro</h3>
          <p :class="styles.logoHint">Workspace console</p>
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
          <div :class="styles.menuLabel">Tổng quan</div>

          <el-menu-item
            v-if="authStore.hasPermission('read:dashboard')"
            index="/"
          >
            <el-icon><Odometer /></el-icon>
            <span>Dashboard</span>
          </el-menu-item>

          <div :class="styles.menuLabel">Hệ thống</div>

          <el-menu-item
            v-if="authStore.hasPermission('read:users')"
            index="/systems/users"
          >
            <el-icon><User /></el-icon>
            <span>Người dùng</span>
          </el-menu-item>

          <el-menu-item
            v-if="authStore.hasPermission('read:roles')"
            index="/systems/roles"
          >
            <el-icon><Box /></el-icon>
            <span>Vai trò</span>
          </el-menu-item>

          <el-menu-item
            v-if="authStore.hasPermission('read:tenants')"
            index="/systems/tenants"
          >
            <el-icon><House /></el-icon>
            <span>Tenant</span>
          </el-menu-item>

          <el-menu-item
            v-if="authStore.hasPermission('read:logs')"
            index="/systems/logs"
          >
            <el-icon><Document /></el-icon>
            <span>Nhật ký</span>
          </el-menu-item>
        </el-menu>
      </nav>

      <div :class="styles.sidebarFooter">
        <span :class="styles.sidebarBrand">Admin Pro</span>
        <span :class="styles.sidebarVersion">v1.0</span>
      </div>
    </el-aside>

    <el-container :class="styles.mainWrapper">
      <el-header :class="styles.header">
        <div :class="styles.headerLeft">
          <h1 :class="styles.pageTitle">{{ pageTitle }}</h1>
        </div>

        <div :class="styles.headerRight">
          <el-switch
            v-model="isDark"
            inline-prompt
            :class="styles.themeSwitch"
            style="--el-switch-on-color: #334155; --el-switch-off-color: #3b82f6;"
            :active-icon="Moon"
            :inactive-icon="Sunny"
          />

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
                  <el-icon><User /></el-icon>Hồ sơ cá nhân
                </el-dropdown-item>
                <el-dropdown-item divided command="logout">
                  <el-icon><SwitchButton /></el-icon>Đăng xuất
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
        © {{ new Date().getFullYear() }} Admin Pro
      </el-footer>
    </el-container>
  </el-container>
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
  Sunny,
  Moon,
  Odometer,
  ArrowDown,
  SwitchButton
} from '@element-plus/icons-vue';
import { useDark } from '@vueuse/core';
import styles from './default.module.scss';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const isDark = useDark();

const pageTitles: Record<string, string> = {
  '/': 'Tổng quan hệ thống',
  '/profile': 'Hồ sơ cá nhân',
  '/systems/users': 'Quản lý Người dùng',
  '/systems/roles': 'Quản lý vai trò',
  '/systems/tenants': 'Quản lý Tenant',
  '/systems/logs': 'Nhật ký hệ thống'
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
    return 'Phân quyền vai trò';
  }
  return pageTitles[route.path] || route.path.split('/').filter(Boolean).pop() || 'Admin Pro';
});

const handleLogout = async () => {
  authStore.logout();
  await router.push('/login');
};

const handleCommand = (command: string) => {
  if (command === 'logout') {
    handleLogout();
  } else if (command === 'profile') {
    router.push('/profile');
  }
};
</script>
