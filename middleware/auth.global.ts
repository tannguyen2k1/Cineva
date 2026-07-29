import { defineNuxtRouteMiddleware, navigateTo, useCookie } from '#imports'

export default defineNuxtRouteMiddleware((to) => {
  const loggedIn = useCookie('auth_logged_in')

  if (!loggedIn.value && to.path !== '/login') {
    return navigateTo('/login')
  }

  if (loggedIn.value && to.path === '/login') {
    return navigateTo('/')
  }
})
