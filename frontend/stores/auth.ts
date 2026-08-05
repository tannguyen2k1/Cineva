import { defineStore } from 'pinia'

import { apiFetch } from '~/utils/apiFetch'

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
    },

    setAuth(user: User, permissions: string[] = []) {
      this.user = user
      this.permissions = permissions
      this.loggedIn = true

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

        const { data } = await apiFetch<any>('/api/auth/me', { headers })
        if (data) {
          this.user = data.user
          this.permissions = data.permissions
        }
      } catch (err: any) {
        const status = err?.response?.status || err?.statusCode
        if (status === 401) {
          const refreshed = await this.tryRefresh()
          if (refreshed) return
        }
        if (import.meta.client) {
          await this.logout()
        } else {
          this.user = null
          this.permissions = []
          this.loggedIn = false
        }
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
          const { data } = await apiFetch<any>('/api/auth/refresh', { method: 'POST' })
          if (data) {
            this.user = data.user
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
        await apiFetch('/api/auth/logout', { method: 'POST' })
      } catch {
        // best-effort
      }

      this.user = null
      this.permissions = []
      this.loggedIn = false

      if (!import.meta.client) return

      const authIndicator = useCookie('auth_logged_in')
      authIndicator.value = null

      await navigateTo('/login')
    }
  }
})
