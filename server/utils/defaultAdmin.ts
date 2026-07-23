/** Tài khoản admin mặc định khi seed / tạo tenant mới — lấy từ .env */
export function getDefaultAdminCredentials() {
  const username = (process.env.DEFAULT_ADMIN_USERNAME || '').trim()
  const password = (process.env.DEFAULT_ADMIN_PASSWORD || '').trim()

  if (!username || !password) {
    throw new Error(
      'Thiếu DEFAULT_ADMIN_USERNAME hoặc DEFAULT_ADMIN_PASSWORD trong .env'
    )
  }

  return { username, password }
}
