/**
 * Shared API client: attaches the double-submit CSRF header on mutating requests.
 *
 * Nuxt exposes `$fetch` as a snapshot of `globalThis.$fetch`, so a plugin cannot
 * retrofit interceptors onto it — app code must call this instance instead.
 */

const CSRF_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE'])

function readCsrfToken(): string | null {
  if (!import.meta.client) return null
  const match = document.cookie.match(/(?:^|;\s*)csrf_token=([^;]*)/)
  return match?.[1] ? decodeURIComponent(match[1]) : null
}

export const apiFetch = $fetch.create({
  onRequest({ options }) {
    const method = String(options.method || 'GET').toUpperCase()
    if (!CSRF_METHODS.has(method)) return

    const token = readCsrfToken()
    if (!token) return

    const headers = new Headers(options.headers as HeadersInit)
    if (!headers.has('X-CSRF-Token')) {
      headers.set('X-CSRF-Token', token)
    }
    options.headers = headers
  }
})
