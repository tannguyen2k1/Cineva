/**
 * Attach X-CSRF-Token on mutating $fetch calls (double-submit cookie).
 * Cookie `csrf_token` is set by FastAPI on login/refresh (readable, not httpOnly).
 */
export default defineNuxtPlugin(() => {
  const csrfMethods = new Set(['POST', 'PUT', 'PATCH', 'DELETE'])

  globalThis.$fetch = $fetch.create({
    onRequest({ options }) {
      const method = String(options.method || 'GET').toUpperCase()
      if (!csrfMethods.has(method)) return

      const csrf = useCookie('csrf_token')
      if (!csrf.value) return

      const headers = new Headers(options.headers as HeadersInit)
      if (!headers.has('X-CSRF-Token')) {
        headers.set('X-CSRF-Token', csrf.value)
      }
      options.headers = headers
    }
  })
})
