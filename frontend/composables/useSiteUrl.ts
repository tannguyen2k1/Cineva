export function useSiteUrl() {
  const config = useRuntimeConfig()
  const siteUrl = String(config.public.siteUrl || 'http://localhost:3000').replace(/\/$/, '')
  return {
    siteUrl,
    absoluteUrl: (path = '/') => {
      const p = path.startsWith('/') ? path : `/${path}`
      return `${siteUrl}${p}`
    }
  }
}
