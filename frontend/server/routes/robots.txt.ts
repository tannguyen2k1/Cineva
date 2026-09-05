export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const siteUrl = String(config.public.siteUrl || 'http://localhost:3000').replace(/\/$/, '')

  const body = [
    'User-agent: *',
    'Allow: /',
    'Allow: /phim',
    'Allow: /phim/',
    'Allow: /tim-kiem',
    '',
    'Disallow: /api/',
    'Disallow: /dashboard',
    'Disallow: /dashboard/',
    'Disallow: /films',
    'Disallow: /films/',
    'Disallow: /systems',
    'Disallow: /systems/',
    'Disallow: /settings',
    'Disallow: /profile',
    'Disallow: /login',
    'Disallow: /register',
    'Disallow: /tu-phim',
    'Disallow: /da-xem',
    'Disallow: /xem',
    'Disallow: /xem/',
    '',
    `Sitemap: ${siteUrl}/sitemap.xml`,
    ''
  ].join('\n')

  setHeader(event, 'Content-Type', 'text/plain; charset=utf-8')
  setHeader(event, 'Cache-Control', 'public, max-age=3600')
  return body
})
