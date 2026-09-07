import { defineNuxtRouteMiddleware, navigateTo, useCookie } from '#imports'

import { requestHasCookie } from '~/utils/authCookies'

const PUBLIC_EXACT = new Set(['/', '/login', '/register', '/tim-kiem'])
const PUBLIC_PREFIXES = [
  '/phim',
  '/xem',
  '/the-loai',
  '/quoc-gia',
  '/nam',
  '/danh-sach'
]

function isPublicPath(path: string): boolean {
  if (PUBLIC_EXACT.has(path)) return true
  return PUBLIC_PREFIXES.some((p) => path === p || path.startsWith(`${p}/`))
}

export default defineNuxtRouteMiddleware((to) => {
  const authStore = useAuthStore()
  const authIndicator = useCookie('auth_logged_in')

  let isLoggedIn = authIndicator.value === '1' || (import.meta.client && authStore.loggedIn)

  if (!isLoggedIn && import.meta.server) {
    // auth_token may have expired (15m); auth_logged_in / refresh still mean a session.
    isLoggedIn =
      requestHasCookie('auth_token') || requestHasCookie('auth_logged_in')
  }

  if (!isLoggedIn && !isPublicPath(to.path)) {
    return navigateTo('/login')
  }

  if (isLoggedIn && (to.path === '/login' || to.path === '/register')) {
    return navigateTo('/')
  }
})
