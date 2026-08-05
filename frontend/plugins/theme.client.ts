import { useDark } from '@vueuse/core'

/**
 * Ensure VueUse color-scheme stays in sync with the blocking head script
 * (avoids hydration flash when toggling dark/light).
 */
export default defineNuxtPlugin(() => {
  useDark()
})
