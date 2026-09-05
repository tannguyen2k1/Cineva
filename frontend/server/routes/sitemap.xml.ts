type SitemapFilm = { slug: string; updatedAt?: string | null }

function esc(s: string) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
}

function urlEntry(loc: string, lastmod?: string | null, changefreq = 'weekly', priority = '0.7') {
  const last = lastmod ? `\n    <lastmod>${esc(lastmod.slice(0, 10))}</lastmod>` : ''
  return `  <url>
    <loc>${esc(loc)}</loc>${last}
    <changefreq>${changefreq}</changefreq>
    <priority>${priority}</priority>
  </url>`
}

export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const siteUrl = String(config.public.siteUrl || 'http://localhost:3000').replace(/\/$/, '')
  const apiBase = String(config.apiProxy || 'http://127.0.0.1:8000').replace(/\/$/, '')

  let films: SitemapFilm[] = []
  try {
    const res = await $fetch<{ success: boolean; data: SitemapFilm[] }>(
      `${apiBase}/api/public/sitemap`
    )
    films = res?.data || []
  } catch {
    films = []
  }

  const staticUrls = [
    urlEntry(`${siteUrl}/`, null, 'daily', '1.0'),
    urlEntry(`${siteUrl}/phim`, null, 'daily', '0.9'),
    urlEntry(`${siteUrl}/tim-kiem`, null, 'weekly', '0.5')
  ]

  const filmUrls = films
    .filter((f) => f.slug)
    .map((f) =>
      urlEntry(`${siteUrl}/phim/${encodeURIComponent(f.slug)}`, f.updatedAt, 'weekly', '0.8')
    )

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${[...staticUrls, ...filmUrls].join('\n')}
</urlset>
`

  setHeader(event, 'Content-Type', 'application/xml; charset=utf-8')
  setHeader(event, 'Cache-Control', 'public, max-age=1800')
  return xml
})
