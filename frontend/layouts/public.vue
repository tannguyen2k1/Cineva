<template>
  <div ref="rootEl" :class="styles.root">
    <header :class="styles.header">
      <div :class="styles.headerInner">
        <NuxtLink to="/" :class="styles.brand" :title="t('app.name')">
          <img
            src="/brand/cineva-mark.svg"
            alt=""
            width="36"
            height="36"
            :class="styles.brandLogo"
          />
          <span :class="styles.brandText">
            <strong>{{ t('app.name') }}</strong>
            <small>{{ t('app.tagline') }}</small>
          </span>
        </NuxtLink>

        <div :class="styles.searchSlot">
          <HeaderSearch />
        </div>

        <nav :class="styles.menu">
          <NuxtLink to="/phim">{{ t('cineva.movies') }}</NuxtLink>
          <NuxtLink to="/phim?type=phim-le">{{ t('cineva.moviesSingle') }}</NuxtLink>
          <NuxtLink to="/phim?type=phim-bo">{{ t('cineva.moviesSeries') }}</NuxtLink>

          <div
            :class="[styles.mega, openMenu === 'genres' ? styles.megaOpen : '']"
            @mouseenter="openNav('genres')"
            @mouseleave="scheduleCloseNav"
          >
            <button type="button" :class="styles.menuDrop" :aria-expanded="openMenu === 'genres'">
              {{ t('cineva.genres') }}
              <span :class="styles.chev" aria-hidden="true" />
            </button>
            <div :class="[styles.megaPanel, styles.megaWide]" role="menu">
              <NuxtLink
                v-for="g in navGenres"
                :key="g.slug"
                :to="`/phim?genre=${g.slug}`"
                role="menuitem"
                @click="closeNav"
              >
                {{ g.name }}
              </NuxtLink>
              <NuxtLink
                v-if="navGenres.length"
                :to="'/phim'"
                :class="styles.megaAll"
                role="menuitem"
                @click="closeNav"
              >
                {{ t('cineva.viewAll') }} →
              </NuxtLink>
            </div>
          </div>

          <div
            :class="[styles.mega, openMenu === 'countries' ? styles.megaOpen : '']"
            @mouseenter="openNav('countries')"
            @mouseleave="scheduleCloseNav"
          >
            <button type="button" :class="styles.menuDrop" :aria-expanded="openMenu === 'countries'">
              {{ t('cineva.countries') }}
              <span :class="styles.chev" aria-hidden="true" />
            </button>
            <div :class="[styles.megaPanel, styles.megaNarrow]" role="menu">
              <NuxtLink
                v-for="c in navCountries"
                :key="c.slug"
                :to="`/phim?country=${c.slug}`"
                role="menuitem"
                @click="closeNav"
              >
                {{ c.name }}
              </NuxtLink>
            </div>
          </div>
        </nav>

        <div :class="styles.actions">
          <NuxtLink v-if="!authStore.isLoggedIn" to="/login" :class="styles.memberBtn">
            {{ t('cineva.member') }}
          </NuxtLink>
          <template v-else>
            <HeaderNotifications />
            <el-dropdown
              trigger="click"
              popper-class="cineva-dark-select"
              @command="onCommand"
            >
              <button type="button" :class="styles.userTrigger">
                <UserProfile
                  :username="authStore.user?.username || ''"
                  :full-name="authStore.user?.fullName"
                  :avatar="authStore.user?.avatar"
                  :size="32"
                  :text-class="styles.userName"
                />
                <el-icon :class="styles.userChevron"><ArrowDown /></el-icon>
              </button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="profile">{{ t('header.profile') }}</el-dropdown-item>
                  <el-dropdown-item command="watched">{{ t('cineva.watched') }}</el-dropdown-item>
                  <el-dropdown-item command="watchlist">{{ t('cineva.watchlist') }}</el-dropdown-item>
                  <el-dropdown-item
                    v-if="authStore.hasPermission('read:dashboard')"
                    command="admin"
                    divided
                  >
                    {{ t('cineva.admin') }}
                  </el-dropdown-item>
                  <el-dropdown-item
                    command="logout"
                    :divided="!authStore.hasPermission('read:dashboard')"
                  >
                    {{ t('header.logout') }}
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </div>
      </div>
    </header>

    <main :class="styles.main">
      <slot />
    </main>

    <footer :class="styles.footer">
      <div :class="styles.footerGlow" aria-hidden="true" />
      <div :class="styles.footerInner">
        <div :class="styles.footerBrand">
          <NuxtLink to="/" :class="styles.footerLogo">
            <img
              src="/brand/cineva-mark.svg"
              alt=""
              width="40"
              height="40"
              :class="styles.brandLogo"
            />
            <span>
              <strong>{{ t('app.name') }}</strong>
              <small>{{ t('app.tagline') }}</small>
            </span>
          </NuxtLink>
          <p>{{ t('cineva.footerBlurb') }}</p>
        </div>

        <div :class="styles.footerCol">
          <h3>{{ t('cineva.footerExplore') }}</h3>
          <NuxtLink to="/phim">{{ t('cineva.movies') }}</NuxtLink>
          <NuxtLink to="/phim?type=phim-le">{{ t('cineva.moviesSingle') }}</NuxtLink>
          <NuxtLink to="/phim?type=phim-bo">{{ t('cineva.moviesSeries') }}</NuxtLink>
          <NuxtLink to="/phim?type=dang-chieu">{{ t('cineva.nowShowing') }}</NuxtLink>
          <NuxtLink v-if="authStore.isLoggedIn" to="/da-xem">{{ t('cineva.watched') }}</NuxtLink>
          <NuxtLink v-if="authStore.isLoggedIn" to="/tu-phim">{{ t('cineva.watchlist') }}</NuxtLink>
        </div>

        <div :class="styles.footerCol">
          <h3>{{ t('cineva.genres') }}</h3>
          <NuxtLink
            v-for="g in footerGenres"
            :key="g.slug"
            :to="`/phim?genre=${g.slug}`"
          >
            {{ g.name }}
          </NuxtLink>
          <NuxtLink to="/phim" :class="styles.footerMore">{{ t('cineva.viewAll') }} →</NuxtLink>
        </div>

        <div :class="styles.footerCol">
          <h3>{{ t('cineva.countries') }}</h3>
          <NuxtLink
            v-for="c in footerCountries"
            :key="c.slug"
            :to="`/phim?country=${c.slug}`"
          >
            {{ c.name }}
          </NuxtLink>
        </div>
      </div>

      <div :class="styles.footerBottom">
        <span>{{ t('app.footer', { year: new Date().getFullYear() }) }}</span>
        <span>{{ t('cineva.footerNote') }}</span>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { ArrowDown } from '@element-plus/icons-vue'
import styles from './public.module.scss'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const rootEl = ref<HTMLElement | null>(null)
const openMenu = ref<'genres' | 'countries' | null>(null)
let closeNavTimer: ReturnType<typeof setTimeout> | null = null

function openNav(menu: 'genres' | 'countries') {
  if (closeNavTimer) {
    clearTimeout(closeNavTimer)
    closeNavTimer = null
  }
  openMenu.value = menu
}

function scheduleCloseNav() {
  if (closeNavTimer) clearTimeout(closeNavTimer)
  closeNavTimer = setTimeout(() => {
    openMenu.value = null
    closeNavTimer = null
  }, 180)
}

function closeNav() {
  if (closeNavTimer) {
    clearTimeout(closeNavTimer)
    closeNavTimer = null
  }
  openMenu.value = null
}

type TaxonomyItem = { slug: string; name: string }
type TaxonomiesResponse = {
  success: boolean
  data: {
    genres: TaxonomyItem[]
    countries: TaxonomyItem[]
    types: TaxonomyItem[]
  }
}

const { data: tax } = await useAsyncData('public-taxonomies-nav', () =>
  $fetch<TaxonomiesResponse>('/api/public/taxonomies')
)

const navGenres = computed(() => tax.value?.data?.genres || [])
const navCountries = computed(() => tax.value?.data?.countries || [])
const footerGenres = computed(() => navGenres.value.slice(0, 6))
const footerCountries = computed(() => navCountries.value.slice(0, 6))

watch(
  () => route.fullPath,
  async (path) => {
    closeNav()
    if (!import.meta.client) return

    await nextTick()
    if (rootEl.value) rootEl.value.scrollTop = 0
    window.scrollTo(0, 0)

    try {
      await useApiFetch('/api/public/traffic/hit', {
        method: 'POST',
        body: {
          path,
          referrer: document.referrer || null,
          language: navigator.language || null
        }
      })
    } catch {
      // ignore tracking failures
    }
  },
  { immediate: true }
)

async function onCommand(cmd: string) {
  if (cmd === 'profile') {
    await router.push('/profile')
    return
  }
  if (cmd === 'watched') {
    await router.push('/da-xem')
    return
  }
  if (cmd === 'watchlist') {
    await router.push('/tu-phim')
    return
  }
  if (cmd === 'admin') {
    await router.push('/dashboard')
    return
  }
  if (cmd === 'logout') {
    await authStore.logout()
    await router.push('/')
  }
}
</script>
