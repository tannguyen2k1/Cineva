import { defineNuxtPlugin } from '#app'
import { useAuthStore } from '../stores/auth'

export default defineNuxtPlugin(async () => {
  const authStore = useAuthStore()

  authStore.initAuth()

  if (authStore.loggedIn && !authStore.user) {
    await authStore.fetchUser()
  }
})
