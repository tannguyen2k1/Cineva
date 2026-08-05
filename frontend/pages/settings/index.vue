<template>
  <div :class="styles.menuPage">
    <!-- Header -->
    <div :class="styles.header">
      <div :class="styles.headerText">
        <h1 :class="styles.title">Khám phá thêm</h1>
        <p :class="styles.subtitle">Truy cập nhanh các khu vực khác của hệ thống.</p>
      </div>
      <ThemeSwitcher />
    </div>

    <!-- Profile Card -->
    <div :class="styles.profileCard" @click="router.push('/profile')">
      <UserProfile
        :username="authStore.user?.username || ''"
        :full-name="authStore.user?.fullName"
        :avatar="authStore.user?.avatar"
        :size="48"
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
      <div v-if="authStore.hasPermission('read:users')" :class="styles.listItem" @click="router.push('/systems/users')">
        <el-icon><UserFilled /></el-icon>
        <span>{{ t('pages.users') }}</span>
        <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
      </div>
      <div v-if="authStore.hasPermission('read:roles')" :class="styles.listItem" @click="router.push('/systems/roles')">
        <el-icon><Setting /></el-icon>
        <span>{{ t('pages.roles') }}</span>
        <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
      </div>
      <div v-if="authStore.hasPermission('read:logs')" :class="styles.listItem" @click="router.push('/systems/logs')">
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
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { ArrowRight, DataLine, Box, Tickets, User, Star, ChatLineRound, UserFilled, Setting, Document, SwitchButton } from '@element-plus/icons-vue';
import styles from './settings.module.scss';

const authStore = useAuthStore();
const router = useRouter();
const { t } = useI18n();

const handleLogout = async () => {
  authStore.logout();
  await router.push('/login');
};
</script>
