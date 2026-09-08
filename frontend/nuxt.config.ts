// https://nuxt.com/docs/api/configuration/nuxt-config
import process from 'node:process'

const apiProxy = process.env.NUXT_API_PROXY || 'http://127.0.0.1:8000'
/** Native browser WebSocket cannot rely on Vite/Nitro HTTP proxy — connect to FastAPI directly. */
const wsBaseDefault = apiProxy.replace(/^http/, 'ws')

export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: false },

  app: {
    head: {
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover' },
        { name: 'color-scheme', content: 'dark' },
        { name: 'theme-color', content: '#0b0b0f' },
        { name: 'mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-status-bar-style', content: 'black' },
        { name: 'apple-mobile-web-app-title', content: 'Cineva' }
      ],
      link: [
        { rel: 'icon', type: 'image/svg+xml', href: '/brand/cineva-mark.svg' },
        { rel: 'apple-touch-icon', href: '/brand/cineva-pwa-192.png' },
        { rel: 'manifest', href: '/manifest.webmanifest' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: 'anonymous' },
        { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Outfit:wght@400;500;600;700&display=swap' }
      ],
      // Force dark before first paint
      script: [{ src: '/theme-init.js', tagPosition: 'head' }]
    }
  },

  css: [
    'element-plus/dist/index.css',
    '~/assets/scss/main.scss'
  ],

  modules: [
    '@element-plus/nuxt',
    '@pinia/nuxt',
    '@vueuse/nuxt',
    '@nuxtjs/turnstile',
    '@nuxtjs/i18n'
  ],
  elementPlus: {
    // Global CSS above — avoid late on-demand style inject (FOUC / broken layout flash)
    importStyle: false
  },

  i18n: {
    locales: [
      { code: 'vi', language: 'vi-VN', name: 'Tiếng Việt', file: 'vi.json' }
    ],
    langDir: 'locales',
    defaultLocale: 'vi',
    strategy: 'no_prefix',
    detectBrowserLanguage: false
  },

  turnstile: {
    // Cloudflare always-pass test key when env missing (local/dev)
    siteKey: process.env.NUXT_PUBLIC_TURNSTILE_SITE_KEY || '1x00000000000000000000AA'
  },

  runtimeConfig: {
    /** Used by server routes (sitemap) to reach FastAPI directly */
    apiProxy,
    public: {
      /** Empty = same-origin /api via Nuxt proxy to FastAPI */
      apiBase: process.env.NUXT_PUBLIC_API_BASE || '',
      /** FastAPI WebSocket base, e.g. ws://127.0.0.1:8000 */
      wsBase: process.env.NUXT_PUBLIC_WS_BASE || wsBaseDefault,
      /** Canonical site origin for SEO (no trailing slash), e.g. https://cineva.example.com */
      siteUrl: process.env.NUXT_PUBLIC_SITE_URL || 'http://localhost:3000'
    }
  },

  nitro: {
    routeRules: {
      '/api/**': { proxy: `${apiProxy}/api/**` },
      '/uploads/films/**': {
        proxy: `${apiProxy}/uploads/films/**`,
        headers: { 'cache-control': 'public, max-age=31536000, immutable' }
      },
      '/uploads/**': { proxy: `${apiProxy}/uploads/**` }
    }
  },

  build: {
    transpile: ['vue3-emoji-picker']
  }
})
