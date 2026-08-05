/**
 * Wrapper around $fetch that auto-refreshes the access token on 401.
 * Usage: const data = await useApiFetch('/api/users')
 */
export async function useApiFetch(url: string, opts?: any): Promise<any> {
  try {
    return await $fetch(url, opts)
  } catch (err: any) {
    const status = err?.response?.status || err?.statusCode
    if (status === 401 && import.meta.client) {
      const authStore = useAuthStore()
      const refreshed = await authStore.tryRefresh()
      if (refreshed) {
        return await $fetch(url, opts)
      }
      authStore.logout()
    }
    throw err
  }
}
