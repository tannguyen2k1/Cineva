import { useDark } from '@vueuse/core'

/** Cineva is dark-only (no light theme toggle). */
export default defineNuxtPlugin(() => {
  const isDark = useDark({ initialValue: 'dark' })
  isDark.value = true
})
