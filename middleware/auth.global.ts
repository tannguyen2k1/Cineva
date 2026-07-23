import { defineNuxtRouteMiddleware, navigateTo, useCookie } from '#imports';

export default defineNuxtRouteMiddleware((to, from) => {
  const token = useCookie('auth_token');

  // Nếu chưa đăng nhập mà vào trang khác login -> redirect về login
  if (!token.value && to.path !== '/login') {
    return navigateTo('/login');
  }

  // Nếu đã đăng nhập mà vào trang login -> redirect về home
  if (token.value && to.path === '/login') {
    return navigateTo('/');
  }
});
