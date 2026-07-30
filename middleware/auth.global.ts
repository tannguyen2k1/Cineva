import { defineNuxtRouteMiddleware, navigateTo, useCookie } from '#imports'

export default defineNuxtRouteMiddleware((to) => {
  const authStore = useAuthStore()
  const authIndicator = useCookie('auth_logged_in')

  let isLoggedIn = authIndicator.value === '1' || (import.meta.client && authStore.loggedIn)

  // SSR fallback: httpOnly cookie readable server-side
  if (!isLoggedIn && import.meta.server) {
    isLoggedIn = !!useCookie('auth_token').value
  }

  if (!isLoggedIn && to.path !== '/login') {
    return navigateTo('/login')
  }

  if (isLoggedIn && to.path === '/login') {
    return navigateTo('/')
  }
})
