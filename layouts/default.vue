<template>
  <el-container :class="styles.layoutContainer">
    <el-aside width="260px" :class="styles.aside">
      <div :class="styles.logo">
        <h3>Admin Pro</h3>
      </div>
      
      <el-menu 
        :default-active="route.path" 
        class="el-menu-vertical"
        style="--el-menu-bg-color: transparent; --el-menu-text-color: var(--text-sidebar); --el-menu-active-color: var(--text-sidebar-active);"
        router
      >
        <div :class="styles.menuLabel" style="margin-top: 10px;">OVERVIEW</div>
        
        <el-menu-item index="/">
          <el-icon><Odometer /></el-icon>
          <span>Dashboard</span>
        </el-menu-item>
        
        <div :class="styles.menuLabel" style="margin-top: 24px;">SYSTEMS</div>
        
        <el-menu-item index="/systems/users">
          <el-icon><User /></el-icon>
          <span>Quản lý người dùng</span>
        </el-menu-item>
        
        <el-menu-item index="/systems/roles" v-if="authStore.permissions.includes('admin:settings')">
          <el-icon><Box /></el-icon>
          <span>Quản lý vai trò</span>
        </el-menu-item>
        
        <el-menu-item index="/systems/tenants" v-if="authStore.permissions.includes('admin:settings')">
          <el-icon><House /></el-icon>
          <span>Quản lý Tenant</span>
        </el-menu-item>
        
        <el-menu-item index="/systems/logs" v-if="authStore.permissions.includes('admin:settings')">
          <el-icon><Document /></el-icon>
          <span>Nhật ký hệ thống</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    
    <el-container :class="styles.mainWrapper">
      <el-header :class="styles.header">
        <div :class="styles.headerLeft">
          <el-breadcrumb separator="/">
            <el-breadcrumb-item :to="{ path: '/' }">Home</el-breadcrumb-item>
            <el-breadcrumb-item :class="styles.fw500">{{ route.path.split('/').pop()?.toUpperCase() || 'DASHBOARD' }}</el-breadcrumb-item>
          </el-breadcrumb>
        </div>
        <div :class="styles.headerRight">
          <!-- Dark Mode Toggle -->
          <el-switch
            v-model="isDark"
            inline-prompt
            style="margin-right: 20px; --el-switch-on-color: #4b5563; --el-switch-off-color: #3b82f6;"
            :active-icon="Moon"
            :inactive-icon="Sunny"
          />

          <el-dropdown trigger="click" @command="handleCommand">
            <div :class="styles.userProfile">
              <el-avatar v-if="authStore.user?.avatar" size="default" :src="authStore.user?.avatar" />
              <el-avatar v-else size="default" style="background-color: var(--primary-color)">{{ authStore.user?.username?.charAt(0).toUpperCase() }}</el-avatar>
              <span :class="styles.userName">{{ authStore.user?.fullName || authStore.user?.username }}</span>
              <el-icon style="margin-left: 8px;"><ArrowDown /></el-icon>
            </div>
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
        © {{ new Date().getFullYear() }} Admin Pro. All rights reserved.
      </el-footer>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { useAuthStore } from '../stores/auth';
import { useRoute, useRouter } from 'vue-router';
import { User, Box, House, Document, Sunny, Moon, Odometer, ArrowDown, SwitchButton } from '@element-plus/icons-vue';
import { useDark } from '@vueuse/core';
import styles from './default.module.scss'; // Import CSS Module

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const isDark = useDark();

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

<style scoped>
/* Override Element Plus Menu styles for the custom look */
.el-menu-vertical {
  border-right: none;
  padding: 0 16px;
}

:deep(.el-menu-item) {
  height: 48px;
  line-height: 48px;
  border-radius: var(--radius-sm);
  margin-bottom: 6px;
  font-size: 14.5px;
  font-weight: 500;
  transition: all 0.2s ease;
}

:deep(.el-menu-item:hover) {
  background-color: var(--bg-sidebar-active) !important;
  color: var(--text-sidebar-active) !important;
}

/* Active State Customization */
:deep(.el-menu-item.is-active) {
  background-color: var(--primary-color) !important;
  color: #fff !important;
  box-shadow: var(--shadow-glow);
  font-weight: 600;
}

:deep(.el-menu-item [class^="el-icon"]) {
  margin-right: 14px;
  font-size: 18px;
}
</style>
