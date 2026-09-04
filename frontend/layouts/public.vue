<template>
  <div ref="rootEl" :class="styles.root">
    <header :class="styles.header">
      <div :class="styles.headerInner">
        <NuxtLink to="/" :class="styles.brand" :title="t('app.name')">
          <span :class="styles.brandMark" aria-hidden="true">C</span>
          <span :class="styles.brandText">
            <strong>{{ t('app.name') }}</strong>
            <small>{{ t('app.tagline') }}</small>
          </span>
        </NuxtLink>

        <form :class="styles.search" @submit.prevent="onSearch">
          <el-icon :class="styles.searchIcon"><Search /></el-icon>
          <input
            v-model="keyword"
            type="search"
            :placeholder="t('cineva.searchPlaceholder')"
            :class="styles.searchInput"
            autocomplete="off"
          />
        </form>

        <nav :class="styles.menu">
          <NuxtLink to="/phim">{{ t('cineva.movies') }}</NuxtLink>
          <NuxtLink to="/phim?type=phim-le">{{ t('cineva.moviesSingle') }}</NuxtLink>
          <NuxtLink to="/phim?type=phim-bo">{{ t('cineva.moviesSeries') }}</NuxtLink>
          <el-dropdown trigger="hover" :teleported="true">
            <span :class="styles.menuDrop">{{ t('cineva.genres') }}</span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item
                  v-for="g in navGenres"
                  :key="g.slug"
                  @click="go(`/phim?genre=${g.slug}`)"
                >
                  {{ g.name }}
                </el-dropdown-item>
                <el-dropdown-item divided @click="go('/phim')">
                  {{ t('cineva.viewAll') }}
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
          <el-dropdown trigger="hover">
            <span :class="styles.menuDrop">{{ t('cineva.countries') }}</span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item
                  v-for="c in navCountries"
                  :key="c.slug"
                  @click="go(`/phim?country=${c.slug}`)"
                >
                  {{ c.name }}
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </nav>

        <div :class="styles.actions">
          <NuxtLink
            v-if="authStore.hasPermission('read:dashboard')"
            to="/dashboard"
            :class="styles.navLink"
          >
            {{ t('cineva.admin') }}
          </NuxtLink>
          <NuxtLink v-if="!authStore.isLoggedIn" to="/login" :class="styles.memberBtn">
            {{ t('cineva.member') }}
          </NuxtLink>
          <el-dropdown v-else trigger="click" @command="onCommand">
            <button type="button" :class="styles.memberBtn">
              {{ authStore.user?.username || t('cineva.member') }}
            </button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="watchlist">{{ t('cineva.watchlist') }}</el-dropdown-item>
                <el-dropdown-item command="logout" divided>{{ t('header.logout') }}</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </div>
    </header>

    <main :class="styles.main">
      <slot />
    </main>

    <footer :class="styles.footer">
      <div :class="styles.footerInner">
        <strong>{{ t('app.name') }}</strong>
        <p>{{ t('cineva.footerBlurb') }}</p>
        <span>{{ t('app.footer', { year: new Date().getFullYear() }) }}</span>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { Search } from '@element-plus/icons-vue'
import styles from './public.module.scss'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const rootEl = ref<HTMLElement | null>(null)
const keyword = ref(typeof route.query.q === 'string' ? route.query.q : '')

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

// Layout scrolls inside .root (body is overflow:hidden), so reset on navigate
watch(
  () => route.fullPath,
  async () => {
    await nextTick()
    if (rootEl.value) rootEl.value.scrollTop = 0
    window.scrollTo(0, 0)
  }
)

function onSearch() {
  const q = keyword.value.trim()
  router.push(q ? { path: '/tim-kiem', query: { q } } : '/phim')
}

function go(path: string) {
  router.push(path)
}

async function onCommand(cmd: string) {
  if (cmd === 'watchlist') {
    await router.push('/tu-phim')
    return
  }
  if (cmd === 'logout') {
    await authStore.logout()
    await router.push('/')
  }
}
</script>
