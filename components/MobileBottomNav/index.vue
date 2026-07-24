<template>
  <nav :class="styles.bottomNav">
    <NuxtLink to="/" :class="[styles.navItem, isActive('/') && styles.active]">
      <el-icon :class="styles.icon"><Menu /></el-icon>
      <span :class="styles.label">{{ t('nav.dashboard') }}</span>
    </NuxtLink>

    <NuxtLink to="/orders" :class="[styles.navItem, isActive('/orders') && styles.active]">
      <el-icon :class="styles.icon"><ShoppingCart /></el-icon>
      <span :class="styles.label">{{ t('nav.orders') }}</span>
    </NuxtLink>

    <NuxtLink to="/products" :class="[styles.navItem, isActive('/products') && styles.active]">
      <el-icon :class="styles.icon"><Goods /></el-icon>
      <span :class="styles.label">{{ t('nav.products') }}</span>
    </NuxtLink>
    
    <NuxtLink to="/customers" :class="[styles.navItem, isActive('/customers') && styles.active]">
      <el-icon :class="styles.icon"><User /></el-icon>
      <span :class="styles.label">{{ t('nav.customers') }}</span>
    </NuxtLink>

    <div :class="[styles.navItem, isDrawerOpen && styles.active]" @click="isDrawerOpen = true">
      <el-icon :class="styles.icon"><MoreFilled /></el-icon>
      <span :class="styles.label">{{ t('nav.menu') }}</span>
    </div>

    <MobileMenuDrawer v-model="isDrawerOpen" />
  </nav>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { Menu, ShoppingCart, Goods, User, MoreFilled } from '@element-plus/icons-vue';
import styles from './MobileBottomNav.module.scss';

const route = useRoute();
const { t } = useI18n();

const isDrawerOpen = ref(false);

const isActive = (path: string) => {
  if (path === '/') return route.path === '/';
  return route.path.startsWith(path);
};
</script>
