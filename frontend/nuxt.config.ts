// https://nuxt.com/docs/api/configuration/nuxt-config
const apiProxy = process.env.NUXT_API_PROXY || 'http://127.0.0.1:8000'
/** Native browser WebSocket cannot rely on Vite/Nitro HTTP proxy — connect to FastAPI directly. */
const wsBaseDefault = apiProxy.replace(/^http/, 'ws')

export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: false },

  app: {
    head: {
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover' }
      ],
      link: [
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: 'anonymous' },
        { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Outfit:wght@400;500;600;700&display=swap' }
      ]
    }
  },

  css: [
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
    // Config cho Element Plus nếu cần
  },

  i18n: {
    locales: [
      { code: 'vi', language: 'vi-VN', name: 'Tiếng Việt', file: 'vi.json' },
      { code: 'en', language: 'en-US', name: 'English', file: 'en.json' }
    ],
    langDir: 'locales',
    defaultLocale: 'vi',
    strategy: 'no_prefix',
    detectBrowserLanguage: {
      useCookie: true,
      cookieKey: 'i18n_redirected',
      redirectOn: 'root',
      fallbackLocale: 'vi'
    }
  },

  turnstile: {
    siteKey: process.env.NUXT_PUBLIC_TURNSTILE_SITE_KEY || ''
  },

  runtimeConfig: {
    public: {
      /** Empty = same-origin /api via Nuxt proxy to FastAPI */
      apiBase: process.env.NUXT_PUBLIC_API_BASE || '',
      /** FastAPI WebSocket base, e.g. ws://127.0.0.1:8000 */
      wsBase: process.env.NUXT_PUBLIC_WS_BASE || wsBaseDefault
    }
  },

  nitro: {
    routeRules: {
      '/api/**': { proxy: `${apiProxy}/api/**` },
      '/uploads/**': { proxy: `${apiProxy}/uploads/**` }
    }
  }
})
