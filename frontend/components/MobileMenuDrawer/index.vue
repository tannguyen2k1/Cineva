<template>
  <el-drawer
    :model-value="modelValue"
    direction="btt"
    size="auto"
    :with-header="false"
    class="mobile-menu-drawer"
    append-to-body
    @update:model-value="emit('update:modelValue', $event)"
  >
    <div :class="styles.menuPage">
      <div :class="styles.header">
        <div :class="styles.headerText">
          <h1 :class="styles.title">{{ t('cineva.mobileMoreTitle') }}</h1>
          <p :class="styles.subtitle">{{ t('cineva.mobileMoreHintAdmin') }}</p>
        </div>
      </div>

      <div :class="styles.profileCard" @click="goTo('/profile')">
        <UserProfile
          :username="authStore.user?.username || ''"
          :full-name="authStore.user?.fullName"
          :avatar="authStore.user?.avatar"
          :size="48"
          :show-name="false"
        />
        <div :class="styles.profileInfo">
          <h3>{{ authStore.user?.fullName || authStore.user?.username }}</h3>
          <p>{{ t('cineva.mobileMoreProfile') }}</p>
        </div>
        <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
      </div>

      <div :class="styles.gridSection">
        <button
          v-if="authStore.hasPermission('read:dashboard')"
          type="button"
          :class="styles.gridCard"
          @click="goTo('/dashboard')"
        >
          <div :class="[styles.iconWrapper, styles.blue]">
            <el-icon><Odometer /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>{{ t('nav.dashboard') }}</h4>
            <p>{{ t('pages.dashboard') }}</p>
          </div>
        </button>

        <button
          v-if="authStore.hasPermission('read:films')"
          type="button"
          :class="styles.gridCard"
          @click="goTo('/films')"
        >
          <div :class="[styles.iconWrapper, styles.yellow]">
            <el-icon><Film /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>{{ t('nav.adminFilms') }}</h4>
            <p>{{ t('pages.adminFilms') }}</p>
          </div>
        </button>

        <button
          v-if="authStore.hasPermission('read:sync')"
          type="button"
          :class="styles.gridCard"
          @click="goTo('/films/sync')"
        >
          <div :class="[styles.iconWrapper, styles.green]">
            <el-icon><Refresh /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>{{ t('nav.sync') }}</h4>
            <p>{{ t('pages.sync') }}</p>
          </div>
        </button>

        <button
          v-if="authStore.hasPermission('read:banners')"
          type="button"
          :class="styles.gridCard"
          @click="goTo('/films/banners')"
        >
          <div :class="[styles.iconWrapper, styles.purple]">
            <el-icon><Picture /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>{{ t('nav.banners') }}</h4>
            <p>{{ t('pages.banners') }}</p>
          </div>
        </button>

        <button
          v-if="authStore.hasPermission('read:featured')"
          type="button"
          :class="styles.gridCard"
          @click="goTo('/films/featured')"
        >
          <div :class="[styles.iconWrapper, styles.pink]">
            <el-icon><Star /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>{{ t('nav.featured') }}</h4>
            <p>{{ t('pages.featured') }}</p>
          </div>
        </button>

        <button
          v-if="authStore.hasPermission('read:comments')"
          type="button"
          :class="styles.gridCard"
          @click="goTo('/films/comments')"
        >
          <div :class="[styles.iconWrapper, styles.teal]">
            <el-icon><ChatDotRound /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>{{ t('nav.commentsAdmin') }}</h4>
            <p>{{ t('pages.commentsAdmin') }}</p>
          </div>
        </button>
      </div>

      <div :class="styles.listSection">
        <button
          v-if="authStore.hasPermission('read:users')"
          type="button"
          :class="styles.listItem"
          @click="goTo('/systems/users')"
        >
          <el-icon><UserFilled /></el-icon>
          <span>{{ t('pages.users') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </button>

        <button
          v-if="authStore.hasPermission('read:roles')"
          type="button"
          :class="styles.listItem"
          @click="goTo('/systems/roles')"
        >
          <el-icon><Setting /></el-icon>
          <span>{{ t('pages.roles') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </button>

        <button
          v-if="authStore.hasPermission('read:logs')"
          type="button"
          :class="styles.listItem"
          @click="goTo('/systems/logs')"
        >
          <el-icon><Document /></el-icon>
          <span>{{ t('pages.logs') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </button>

        <button type="button" :class="styles.listItem" @click="goTo('/')">
          <el-icon><HomeFilled /></el-icon>
          <span>{{ t('cineva.home') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </button>

        <button type="button" :class="[styles.listItem, styles.logout]" @click="handleLogout">
          <el-icon><SwitchButton /></el-icon>
          <span>{{ t('header.logout') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </button>
      </div>
    </div>
  </el-drawer>
</template>

<script setup lang="ts">
import {
  ArrowRight,
  Odometer,
  Film,
  Refresh,
  Picture,
  Star,
  ChatDotRound,
  UserFilled,
  Setting,
  Document,
  SwitchButton,
  HomeFilled
} from '@element-plus/icons-vue'
import styles from './MobileMenuDrawer.module.scss'

defineProps<{
  modelValue: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [boolean]
}>()

const authStore = useAuthStore()
const router = useRouter()
const { t } = useI18n()

function goTo(path: string) {
  emit('update:modelValue', false)
  router.push(path)
}

async function handleLogout() {
  emit('update:modelValue', false)
  authStore.logout()
  await router.push('/login')
}
</script>

<style>
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
