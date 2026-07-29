import { defineNuxtRouteMiddleware, navigateTo, useCookie } from '#imports'

export default defineNuxtRouteMiddleware((to) => {
  let isLoggedIn = useCookie('auth_logged_in').value === '1'

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
