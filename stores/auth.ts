import { defineStore } from 'pinia'

interface User {
  id: string
  username: string
  fullName: string | null
  email?: string | null
  avatar?: string | null
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null as User | null,
    tenant_id: null as string | null,
    permissions: [] as string[],
    loggedIn: false
  }),

  getters: {
    isLoggedIn: (state) => state.loggedIn,
    hasPermission: (state) => (permission: string) => state.permissions.includes(permission)
  },

  actions: {
    initAuth() {
      const indicator = useCookie('auth_logged_in')
      if (indicator.value === '1') {
        this.loggedIn = true
      }
      const tenantCookie = useCookie('tenant_id')
      if (tenantCookie.value) {
        this.tenant_id = tenantCookie.value as string
      }
    },

    setAuth(user: User, tenant_id: string, permissions: string[] = []) {
      this.user = user
      this.tenant_id = tenant_id
      this.permissions = permissions
      this.loggedIn = true

      const tenantCookie = useCookie('tenant_id')
      tenantCookie.value = tenant_id
    },

    async fetchUser() {
      if (!this.loggedIn) return
      try {
        const headers: Record<string, string> = {}
        if (import.meta.server) {
          const cookieHeaders = useRequestHeaders(['cookie'])
          if (cookieHeaders.cookie) {
            headers.cookie = cookieHeaders.cookie
          }
        }

        const { data } = await $fetch<any>('/api/auth/me', { headers })
        if (data) {
          this.user = data.user
          this.tenant_id = data.tenant_id
          this.permissions = data.permissions
        }
      } catch {
        this.logout()
      }
    },

    async refreshToken() {
      try {
        const { data } = await $fetch<any>('/api/auth/refresh', { method: 'POST' })
        if (data) {
          this.user = data.user
          this.tenant_id = data.tenant_id
          this.permissions = data.permissions
          this.loggedIn = true
        }
      } catch {
        this.logout()
      }
    },

    async logout() {
      try {
        await $fetch('/api/auth/logout', { method: 'POST' })
      } catch {
        // best-effort
      }

      this.user = null
      this.tenant_id = null
      this.permissions = []
      this.loggedIn = false

      const tenantCookie = useCookie('tenant_id')
      tenantCookie.value = null

      navigateTo('/login')
    }
  }
})
