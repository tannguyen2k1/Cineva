import { apiFetch } from '~/utils/apiFetch'

/**
 * Wrapper around apiFetch (CSRF-aware) that auto-refreshes the access token on 401.
 * Usage: const data = await useApiFetch('/api/users')
 */
export async function useApiFetch(url: string, opts?: any): Promise<any> {
  try {
    return await apiFetch(url, opts)
  } catch (err: any) {
    const status = err?.response?.status || err?.statusCode
    if (status === 401 && import.meta.client) {
      const authStore = useAuthStore()
      const result = await authStore.tryRefresh()
      if (result === 'ok') {
        return await apiFetch(url, opts)
      }
      if (result === 'unauthorized') {
        await authStore.logout()
      }
    }
    throw err
  }
}
