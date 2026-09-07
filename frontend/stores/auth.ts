import { defineStore } from 'pinia'

import { cookieForwardHeaders, requestHasCookie } from '~/utils/authCookies'
import { apiFetch } from '~/utils/apiFetch'

export interface User {
  id: string
  username: string
  fullName: string | null
  email?: string | null
  avatar?: string | null
}

export type RefreshResult = 'ok' | 'unauthorized' | 'unavailable'

let refreshPromise: Promise<RefreshResult> | null = null

const REFRESH_LOCK = 'nafsc-auth-refresh'

function errorStatus(err: any): number {
  return Number(err?.response?.status || err?.statusCode || 0)
}

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

      if (!this.loggedIn && import.meta.server && requestHasCookie('auth_token')) {
        this.loggedIn = true
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

    async fetchUser(isRetry = false) {
      if (!this.loggedIn) return

      // refresh_token cookie is path=/api/auth — it is NOT sent on document SSR
      // requests. Skipping here lets the client refresh with the real cookie.
      if (import.meta.server && !requestHasCookie('auth_token')) {
        return
      }

      try {
        const { data } = await apiFetch<any>('/api/auth/me', { headers: cookieForwardHeaders() })
        if (data) {
          this.user = data.user
          this.permissions = data.permissions
        }
      } catch (err: any) {
        const status = errorStatus(err)
        if (status === 401 && !isRetry) {
          const result = await this.tryRefresh()
          if (result === 'ok') {
            await this.fetchUser(true)
            return
          }
          if (result === 'unavailable') return
        }
        if (status >= 500 || status === 0) return
        // Only hard-logout in the browser after refresh failed — SSR must not
        // clear the session (client still has refresh_token).
        if (import.meta.client && status === 401) {
          await this.logout()
        }
      }
    },

    /**
     * Rotate the access cookie via refresh_token.
     * De-dupes concurrent calls (same tab + cross-tab via navigator.locks).
     */
    async tryRefresh(): Promise<RefreshResult> {
      const runRefresh = async (): Promise<RefreshResult> => {
        try {
          const res = await apiFetch<any>('/api/auth/refresh', {
            method: 'POST',
            headers: cookieForwardHeaders()
          })
          const data = res?.data ?? res
          if (data?.user) {
            this.user = data.user
            this.permissions = data.permissions ?? []
            this.loggedIn = true
            return 'ok'
          }
          return 'unauthorized'
        } catch (err: any) {
          const status = errorStatus(err)
          if (status === 401) return 'unauthorized'
          return 'unavailable'
        }
      }

      if (import.meta.client && typeof navigator !== 'undefined' && navigator.locks?.request) {
        return navigator.locks.request(REFRESH_LOCK, runRefresh)
      }

      if (refreshPromise) return refreshPromise

      refreshPromise = runRefresh().finally(() => {
        refreshPromise = null
      })
      return refreshPromise
    },

    async refreshToken() {
      const result = await this.tryRefresh()
      if (result === 'unauthorized') await this.logout()
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
