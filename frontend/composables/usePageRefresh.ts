import { onMounted, onBeforeUnmount, inject, provide, ref, type InjectionKey, type Ref } from 'vue'

export type PageRefreshHandler = () => void | Promise<void>

export type PageRefreshApi = {
  register: (handler: PageRefreshHandler) => void
  unregister: (handler: PageRefreshHandler) => void
  run: () => Promise<boolean>
  hasHandler: Ref<boolean>
}

export const PAGE_REFRESH_KEY: InjectionKey<PageRefreshApi> = Symbol('page-refresh')

/** Call once in the default layout. */
export function providePageRefresh() {
  let current: PageRefreshHandler | null = null
  const hasHandler = ref(false)

  const api: PageRefreshApi = {
    hasHandler,
    register(handler) {
      current = handler
      hasHandler.value = true
    },
    unregister(handler) {
      if (current === handler) {
        current = null
        hasHandler.value = false
      }
    },
    async run() {
      if (!current) return false
      await current()
      return true
    }
  }

  provide(PAGE_REFRESH_KEY, api)
  return api
}

/** Register the current page refresh callback for layout PullRefresh. */
export function usePageRefresh(handler: PageRefreshHandler) {
  const api = inject(PAGE_REFRESH_KEY, null)

  onMounted(() => {
    api?.register(handler)
  })

  onBeforeUnmount(() => {
    api?.unregister(handler)
  })
}
