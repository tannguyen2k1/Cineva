import { defineNuxtPlugin } from '#app';
import { useAuthStore } from '../stores/auth';

export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.vueApp.directive('permission', {
    mounted(el, binding) {
      const authStore = useAuthStore();
      const requiredPermission = binding.value;

      if (!authStore.hasPermission(requiredPermission)) {
        // Nếu không có quyền, xóa Element khỏi DOM để bảo mật UI
        el.parentNode?.removeChild(el);
      }
    },
  });
});
