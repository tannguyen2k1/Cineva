export default defineEventHandler((event) => {
  return sendRedirect(event, '/api/docs', 302)
})
