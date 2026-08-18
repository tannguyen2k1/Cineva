import { defineNuxtRouteMiddleware, navigateTo, useCookie } from '#imports'

import { requestHasCookie } from '~/utils/authCookies'

export default defineNuxtRouteMiddleware((to) => {
  const authStore = useAuthStore()
  const authIndicator = useCookie('auth_logged_in')

  let isLoggedIn = authIndicator.value === '1' || (import.meta.client && authStore.loggedIn)

  // SSR: read raw Cookie header — useCookie('auth_token') would re-emit and mangle the HttpOnly JWT
  if (!isLoggedIn && import.meta.server) {
    isLoggedIn = requestHasCookie('auth_token')
  }

  if (!isLoggedIn && to.path !== '/login') {
    return navigateTo('/login')
  }

  if (isLoggedIn && to.path === '/login') {
    return navigateTo('/')
  }
})
