// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  
  app: {
    head: {
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
    '@vueuse/nuxt'
  ],
  elementPlus: {
    // Config cho Element Plus nếu cần
  },

  nitro: {
    experimental: {
      websocket: true
    }
  }
})
