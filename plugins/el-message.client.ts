import { messageConfig } from 'element-plus/es/components/config-provider/src/config-provider.mjs'

export default defineNuxtPlugin(() => {
  messageConfig.placement = 'top-right'
})
