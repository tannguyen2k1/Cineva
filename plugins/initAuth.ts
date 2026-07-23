import { defineNuxtPlugin } from '#app';
import { useAuthStore } from '../stores/auth';

export default defineNuxtPlugin(async (nuxtApp) => {
  const authStore = useAuthStore();
  
  // Khôi phục token từ cookie vào Pinia state
  authStore.initAuth();
  
  // Nếu có token nhưng chưa có dữ liệu user (trường hợp F5 tải lại trang)
  if (authStore.token && !authStore.user) {
    await authStore.fetchUser();
  }
});
