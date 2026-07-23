import { defineStore } from 'pinia';

interface User {
  id: string;
  username: string;
  fullName: string | null;
  email?: string | null;
  avatar?: string | null;
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null as User | null,
    tenant_id: null as string | null,
    token: null as string | null,
    permissions: [] as string[]
  }),
  
  getters: {
    isLoggedIn: (state) => !!state.token,
    hasPermission: (state) => (permission: string) => state.permissions.includes(permission)
  },

  actions: {
    initAuth() {
      const tokenCookie = useCookie('auth_token');
      const tenantCookie = useCookie('tenant_id');
      if (tokenCookie.value) {
        this.token = tokenCookie.value as string;
      }
      if (tenantCookie.value) {
        this.tenant_id = tenantCookie.value as string;
      }
    },

    setAuth(token: string, user: User, tenant_id: string, permissions: string[] = []) {
      this.token = token;
      this.user = user;
      this.tenant_id = tenant_id;
      this.permissions = permissions;
      
      const tokenCookie = useCookie('auth_token', { maxAge: 60 * 60 * 2 });
      tokenCookie.value = token;

      const tenantCookie = useCookie('tenant_id');
      tenantCookie.value = tenant_id;
    },
    
    async fetchUser() {
      if (!this.token) return;
      try {
        const headers: any = {
          'Authorization': `Bearer ${this.token}`
        };
        if (import.meta.server) {
          const cookieHeaders = useRequestHeaders(['cookie']);
          Object.assign(headers, cookieHeaders);
        }
        
        const { data } = await $fetch<any>('/api/auth/me', { headers });
        if (data) {
          this.user = data.user;
          this.tenant_id = data.tenant_id;
          this.permissions = data.permissions;
        }
      } catch (err) {
        this.logout();
      }
    },

    logout() {
      this.token = null;
      this.user = null;
      this.tenant_id = null;
      this.permissions = [];
      
      const tokenCookie = useCookie('auth_token');
      tokenCookie.value = null;
      const tenantCookie = useCookie('tenant_id');
      tenantCookie.value = null;
      
      navigateTo('/login');
    }
  }
});
