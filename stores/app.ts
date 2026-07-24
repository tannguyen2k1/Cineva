import { defineStore } from 'pinia';
import { useWindowSize } from '@vueuse/core';
import { computed } from 'vue';

export const useAppStore = defineStore('app', () => {
  const { width } = useWindowSize();

  const isMobile = computed(() => width.value <= 768);
  const isTablet = computed(() => width.value > 768 && width.value <= 1024);
  const isDesktop = computed(() => width.value > 1024);

  return {
    isMobile,
    isTablet,
    isDesktop
  };
});
