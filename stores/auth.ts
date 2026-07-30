import { defineStore } from 'pinia'

interface User {
  id: string
  username: string
  fullName: string | null
  email?: string | null
  avatar?: string | null
}

let refreshPromise: Promise<boolean> | null = null

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

      if (!this.loggedIn && import.meta.server) {
        const authCookie = useCookie('auth_token')
        if (authCookie.value) {
          this.loggedIn = true
        }
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

      // Sync indicator cookie immediately so route middleware sees logged-in state
      // before the Set-Cookie from the login response is reflected in useCookie.
      const authIndicator = useCookie('auth_logged_in', {
        sameSite: 'lax',
        path: '/',
        maxAge: 7 * 24 * 60 * 60
      })
      authIndicator.value = '1'
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
      } catch (err: any) {
        const status = err?.response?.status || err?.statusCode
        if (status === 401) {
          const refreshed = await this.tryRefresh()
          if (refreshed) return
        }
        this.logout()
      }
    },

    /**
     * Try to refresh the access token using the refresh_token cookie.
     * De-dupes concurrent calls so only one refresh request fires.
     * Returns true if refresh succeeded.
     */
    async tryRefresh(): Promise<boolean> {
      if (refreshPromise) return refreshPromise

      refreshPromise = (async () => {
        try {
          const { data } = await $fetch<any>('/api/auth/refresh', { method: 'POST' })
          if (data) {
            this.user = data.user
            this.tenant_id = data.tenant_id
            this.permissions = data.permissions
            this.loggedIn = true
            return true
          }
          return false
        } catch {
          return false
        }
      })()

      const result = await refreshPromise
      refreshPromise = null
      return result
    },

    async refreshToken() {
      const ok = await this.tryRefresh()
      if (!ok) this.logout()
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

      const authIndicator = useCookie('auth_logged_in')
      authIndicator.value = null

      navigateTo('/login')
    }
  }
})
