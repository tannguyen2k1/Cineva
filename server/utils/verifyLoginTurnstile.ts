import type { H3Event } from 'h3'

type TurnstileValidationResponse = {
  success: boolean
  'error-codes'?: string[]
  challenge_ts?: string
  hostname?: string
  action?: string
  cdata?: string
}

/**
 * Verify Cloudflare Turnstile (tên khác để không đụng auto-import
 * `verifyTurnstileToken` từ @nuxtjs/turnstile).
 */
export async function verifyLoginTurnstile(
  token: string,
  event?: H3Event
): Promise<TurnstileValidationResponse> {
  const secretKey = useRuntimeConfig(event).turnstile?.secretKey as string | undefined

  if (!secretKey) {
    throw createError({
      statusCode: 500,
      statusMessage: 'Thiếu NUXT_TURNSTILE_SECRET_KEY'
    })
  }

  return await $fetch<TurnstileValidationResponse>(
    'https://challenges.cloudflare.com/turnstile/v0/siteverify',
    {
      method: 'POST',
      body: `secret=${encodeURIComponent(secretKey)}&response=${encodeURIComponent(token)}`,
      headers: {
        'content-type': 'application/x-www-form-urlencoded'
      }
    }
  )
}
