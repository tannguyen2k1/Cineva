<template>
  <el-drawer
    :model-value="modelValue"
    @update:model-value="$emit('update:modelValue', $event)"
    direction="btt"
    size="auto"
    :with-header="false"
    :class="styles.drawer"
    class="mobile-menu-drawer"
    append-to-body
  >


    <div :class="styles.menuPage">
      <!-- Header -->
      <div :class="styles.header">
        <div :class="styles.headerText">
          <h1 :class="styles.title">Khám phá thêm</h1>
          <p :class="styles.subtitle">Truy cập nhanh các khu vực khác của hệ thống.</p>
        </div>
      </div>

      <!-- Profile Card -->
      <div :class="styles.profileCard" @click="goTo('/profile')">
        <UserProfile
          :username="authStore.user?.username || ''"
          :full-name="authStore.user?.fullName"
          :avatar="authStore.user?.avatar"
          :size="48"
          :show-name="false"
        />
        <div :class="styles.profileInfo">
          <h3>{{ authStore.user?.fullName || authStore.user?.username || 'root' }}</h3>
          <p>Xem hồ sơ và cài đặt tài khoản</p>
        </div>
        <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
      </div>

      <!-- Grid Quick Links -->
      <div :class="styles.gridSection">
        <div :class="styles.gridCard">
          <div :class="[styles.iconWrapper, styles.blue]">
            <el-icon><DataLine /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>BC Doanh thu</h4>
            <p>Thống kê dòng tiền</p>
          </div>
        </div>
        <div :class="styles.gridCard">
          <div :class="[styles.iconWrapper, styles.yellow]">
            <el-icon><Box /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>BC Sản phẩm</h4>
            <p>Thống kê sản phẩm</p>
          </div>
        </div>
        <div :class="styles.gridCard">
          <div :class="[styles.iconWrapper, styles.green]">
            <el-icon><Tickets /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>BC Đơn hàng</h4>
            <p>Theo dõi đơn hàng</p>
          </div>
        </div>
        <div :class="styles.gridCard">
          <div :class="[styles.iconWrapper, styles.purple]">
            <el-icon><User /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>BC Khách hàng</h4>
            <p>Phân tích khách</p>
          </div>
        </div>
        <div :class="styles.gridCard">
          <div :class="[styles.iconWrapper, styles.pink]">
            <el-icon><Star /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>Đánh giá</h4>
            <p>Phản hồi từ khách</p>
          </div>
        </div>
        <div :class="styles.gridCard">
          <div :class="[styles.iconWrapper, styles.teal]">
            <el-icon><ChatLineRound /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>Bình luận</h4>
            <p>Hỏi đáp & Hỗ trợ</p>
          </div>
        </div>
      </div>

      <!-- System Links List -->
      <div :class="styles.listSection">
        <div v-if="authStore.hasPermission('read:sync')" :class="styles.listItem" @click="goTo('/films/sync')">
          <el-icon><Refresh /></el-icon>
          <span>{{ t('pages.sync') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </div>
        <div v-if="authStore.hasPermission('read:films')" :class="styles.listItem" @click="goTo('/films')">
          <el-icon><Film /></el-icon>
          <span>{{ t('pages.adminFilms') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </div>
        <div v-if="authStore.hasPermission('read:banners')" :class="styles.listItem" @click="goTo('/films/banners')">
          <el-icon><Picture /></el-icon>
          <span>{{ t('pages.banners') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </div>
        <div v-if="authStore.hasPermission('read:featured')" :class="styles.listItem" @click="goTo('/films/featured')">
          <el-icon><Star /></el-icon>
          <span>{{ t('pages.featured') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </div>
        <div v-if="authStore.hasPermission('read:comments')" :class="styles.listItem" @click="goTo('/films/comments')">
          <el-icon><ChatDotRound /></el-icon>
          <span>{{ t('pages.commentsAdmin') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </div>
        <div v-if="authStore.hasPermission('read:users')" :class="styles.listItem" @click="goTo('/systems/users')">
          <el-icon><UserFilled /></el-icon>
          <span>{{ t('pages.users') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </div>
        <div v-if="authStore.hasPermission('read:roles')" :class="styles.listItem" @click="goTo('/systems/roles')">
          <el-icon><Setting /></el-icon>
          <span>{{ t('pages.roles') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </div>
        <div v-if="authStore.hasPermission('read:logs')" :class="styles.listItem" @click="goTo('/systems/logs')">
          <el-icon><Document /></el-icon>
          <span>{{ t('pages.logs') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </div>
        <div :class="[styles.listItem, styles.logout]" @click="handleLogout">
          <el-icon><SwitchButton /></el-icon>
          <span>{{ t('header.logout') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </div>
      </div>
    </div>
  </el-drawer>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { ArrowRight, DataLine, Box, Tickets, User, Star, ChatLineRound, UserFilled, Setting, Document, SwitchButton, Refresh, Film, Picture, ChatDotRound } from '@element-plus/icons-vue';
import styles from './MobileMenuDrawer.module.scss';

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const authStore = useAuthStore();
const router = useRouter();
const { t } = useI18n();

const goTo = (path: string) => {
  emit('update:modelValue', false); // Close drawer
  router.push(path);
};

const handleLogout = async () => {
  emit('update:modelValue', false);
  authStore.logout();
  await router.push('/login');
};
</script>

<style>
/* Global override for this drawer */
.mobile-menu-drawer.el-drawer {
  border-top-left-radius: 24px;
  border-top-right-radius: 24px;
  background-color: var(--bg-body) !important;
  margin-bottom: 0 !important;
  bottom: 0 !important;
  box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.05) !important;
}
html.dark .mobile-menu-drawer.el-drawer {
  background-color: var(--bg-body) !important;
  border: 1px solid rgba(255, 255, 255, 0.3) !important;
  border-bottom: none !important;
  box-shadow: 0 -8px 32px rgba(0, 0, 0, 0.8) !important;
}
.mobile-menu-drawer .el-drawer__body {
  padding: 0 !important;
}
</style>
