/** Read incoming Cookie header — never useCookie() on HttpOnly JWT cookies. */
export function requestCookieHeader(): string {
  if (!import.meta.server) return ''
  return useRequestHeaders(['cookie']).cookie || ''
}

export function requestHasCookie(name: string): boolean {
  const raw = requestCookieHeader()
  return new RegExp(`(?:^|;\\s*)${name}=`).test(raw)
}

export function cookieForwardHeaders(): Record<string, string> {
  const headers: Record<string, string> = {}
  const cookie = requestCookieHeader()
  if (cookie) headers.cookie = cookie
  return headers
}
