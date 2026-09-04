import { defineNuxtRouteMiddleware, navigateTo, useCookie } from '#imports'

import { requestHasCookie } from '~/utils/authCookies'

const PUBLIC_EXACT = new Set(['/', '/login', '/dang-ky', '/tim-kiem'])
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
    isLoggedIn = requestHasCookie('auth_token')
  }

  if (!isLoggedIn && !isPublicPath(to.path)) {
    return navigateTo('/login')
  }

  if (isLoggedIn && to.path === '/login') {
    return navigateTo('/')
  }
})
