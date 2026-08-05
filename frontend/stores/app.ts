import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

const MOBILE_MAX = 768;
const TABLET_MAX = 1024;

function readWidth() {
  if (import.meta.client && typeof window !== 'undefined') {
    return window.innerWidth;
  }
  return TABLET_MAX + 1;
}

export const useAppStore = defineStore('app', () => {
  const width = ref(readWidth());

  if (import.meta.client) {
    const onResize = () => {
      width.value = window.innerWidth;
    };
    window.addEventListener('resize', onResize, { passive: true });
  }

  const isMobile = computed(() => width.value <= MOBILE_MAX);
  const isTablet = computed(() => width.value > MOBILE_MAX && width.value <= TABLET_MAX);
  const isDesktop = computed(() => width.value > TABLET_MAX);

  return {
    width,
    isMobile,
    isTablet,
    isDesktop
  };
});
