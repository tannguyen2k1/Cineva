<template>
  <el-drawer
    :model-value="modelValue"
    direction="btt"
    size="auto"
    :with-header="false"
    class="cineva-public-more-menu"
    append-to-body
    @update:model-value="emit('update:modelValue', $event)"
  >
    <div :class="styles.menuPage">
      <div :class="styles.handle" aria-hidden="true" />

      <div :class="styles.header">
        <div :class="styles.headerText">
          <h1 :class="styles.title">{{ t('cineva.mobileMoreTitle') }}</h1>
          <p :class="styles.subtitle">{{ t('cineva.mobileMoreHintAdmin') }}</p>
        </div>
        <div v-if="authStore.isLoggedIn" :class="styles.headerActions">
          <HeaderNotifications />
        </div>
      </div>

      <button
        v-if="authStore.isLoggedIn"
        type="button"
        :class="styles.profileCard"
        @click="goTo('/profile')"
      >
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
      </button>

      <button
        v-else
        type="button"
        :class="styles.profileCard"
        @click="goTo('/login')"
      >
        <span :class="styles.guestAvatar"><el-icon><User /></el-icon></span>
        <div :class="styles.profileInfo">
          <h3>{{ t('cineva.member') }}</h3>
          <p>{{ t('cineva.mobileMoreGuestHint') }}</p>
        </div>
        <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
      </button>

      <div :class="styles.gridSection">
        <NuxtLink to="/phim?type=phim-le" :class="styles.gridCard" @click="close">
          <div :class="[styles.iconWrapper, styles.yellow]">
            <el-icon><Film /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>{{ t('cineva.moviesSingle') }}</h4>
            <p>{{ t('cineva.mobileMoreBrowse') }}</p>
          </div>
        </NuxtLink>

        <NuxtLink to="/phim?type=phim-bo" :class="styles.gridCard" @click="close">
          <div :class="[styles.iconWrapper, styles.purple]">
            <el-icon><Collection /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>{{ t('cineva.moviesSeries') }}</h4>
            <p>{{ t('cineva.mobileMoreBrowse') }}</p>
          </div>
        </NuxtLink>

        <NuxtLink to="/phim?type=dang-chieu" :class="styles.gridCard" @click="close">
          <div :class="[styles.iconWrapper, styles.pink]">
            <el-icon><VideoPlay /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>{{ t('cineva.nowShowing') }}</h4>
            <p>{{ t('cineva.mobileMoreNowHint') }}</p>
          </div>
        </NuxtLink>

        <NuxtLink to="/phim" :class="styles.gridCard" @click="close">
          <div :class="[styles.iconWrapper, styles.blue]">
            <el-icon><Grid /></el-icon>
          </div>
          <div :class="styles.cardText">
            <h4>{{ t('cineva.movies') }}</h4>
            <p>{{ t('cineva.mobileMoreCatalogHint') }}</p>
          </div>
        </NuxtLink>
      </div>

      <div
        v-if="authStore.isLoggedIn || authStore.hasPermission('read:dashboard')"
        :class="styles.listSection"
      >
        <button
          v-if="authStore.hasPermission('read:dashboard')"
          type="button"
          :class="styles.listItem"
          @click="goTo('/dashboard')"
        >
          <el-icon><Setting /></el-icon>
          <span>{{ t('cineva.admin') }}</span>
          <el-icon :class="styles.chevron"><ArrowRight /></el-icon>
        </button>

        <button
          v-if="authStore.isLoggedIn"
          type="button"
          :class="[styles.listItem, styles.logout]"
          @click="handleLogout"
        >
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
  Film,
  Collection,
  VideoPlay,
  Grid,
  User,
  Setting,
  SwitchButton
} from '@element-plus/icons-vue'
import styles from './PublicMobileMoreMenu.module.scss'

defineProps<{
  modelValue: boolean
  genres?: { slug: string; name: string }[]
  countries?: { slug: string; name: string }[]
}>()

const emit = defineEmits<{ 'update:modelValue': [boolean] }>()

const { t } = useI18n()
const router = useRouter()
const authStore = useAuthStore()

function close() {
  emit('update:modelValue', false)
}

function goTo(path: string) {
  close()
  router.push(path)
}

async function handleLogout() {
  close()
  authStore.logout()
  await router.push('/login')
}
</script>

<style>
.cineva-public-more-menu.el-drawer {
  border-top-left-radius: 24px;
  border-top-right-radius: 24px;
  background-color: #0a0a0a !important;
  margin-bottom: 0 !important;
  bottom: 0 !important;
  border: 1px solid rgba(255, 255, 255, 0.3) !important;
  border-bottom: none !important;
  box-shadow: 0 -8px 32px rgba(0, 0, 0, 0.8) !important;
}

.cineva-public-more-menu .el-drawer__body {
  padding: 0 !important;
}
</style>
