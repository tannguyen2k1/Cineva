const IS_PROD = process.env.NODE_ENV === 'production'

defineRouteMeta({
  openAPI: {
    tags: ['Auth'],
    description: 'Clear all auth cookies and end the session.'
  }
})

export default defineEventHandler(async (event) => {
  setCookie(event, 'auth_token', '', { httpOnly: true, secure: IS_PROD, sameSite: 'lax', path: '/', maxAge: 0 })
  setCookie(event, 'refresh_token', '', { httpOnly: true, secure: IS_PROD, sameSite: 'lax', path: '/api/auth', maxAge: 0 })
  setCookie(event, 'auth_logged_in', '', { httpOnly: false, secure: IS_PROD, sameSite: 'lax', path: '/', maxAge: 0 })

  return { success: true }
})
