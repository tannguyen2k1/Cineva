<template>
  <div :class="styles.page">
    <section :class="styles.brand" :aria-label="t('app.name')">
      <div :class="styles.brandMesh" aria-hidden="true" />
      <div :class="styles.brandGrid" aria-hidden="true" />
      <div :class="styles.brandContent">
        <h1 :class="styles.brandName">{{ t('app.name') }}</h1>
        <p :class="styles.brandTagline">{{ t('login.brandTagline') }}</p>
      </div>
    </section>

    <section :class="styles.formPanel">
      <div :class="styles.formInner">
        <header :class="styles.formHeader">
          <div :class="styles.formHeaderTop">
            <h2 :class="styles.formTitle">{{ t('login.title') }}</h2>
            <LocaleSwitcher />
          </div>
          <p :class="styles.formSubtitle">{{ t('login.subtitle') }}</p>
        </header>

        <el-form
          ref="formRef"
          :class="styles.form"
          :model="form"
          :rules="rules"
          label-position="top"
          @submit.prevent
        >
          <el-form-item :label="t('login.username')" prop="username">
            <el-input
              v-model="form.username"
              :placeholder="t('login.usernamePlaceholder')"
              clearable
            />
          </el-form-item>

          <el-form-item :label="t('login.password')" prop="password">
            <el-input
              v-model="form.password"
              type="password"
              :placeholder="t('login.passwordPlaceholder')"
              show-password
              @keyup.enter="handleLogin"
            />
          </el-form-item>

          <el-form-item prop="turnstileToken" :class="styles.turnstileItem">
            <div :class="styles.turnstileWrap">
              <NuxtTurnstile
                :key="turnstileTheme"
                ref="turnstileRef"
                v-model="form.turnstileToken"
                :options="{ theme: turnstileTheme, size: 'normal' }"
              />
            </div>
          </el-form-item>

          <el-form-item :class="styles.submitItem">
            <el-button
              type="primary"
              :loading="loading"
              :class="styles.submitBtn"
              @click="handleLogin"
            >
              {{ t('login.submit') }}
            </el-button>
          </el-form-item>
        </el-form>

        <p :class="styles.formFooter">{{ t('login.footer') }}</p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch } from 'vue';
import { ElMessage } from 'element-plus';
import { useDark } from '@vueuse/core';
import styles from './login.module.scss';

definePageMeta({
  layout: false
});

const { t } = useI18n();
const authStore = useAuthStore();
const formRef = ref();
const turnstileRef = ref<{ reset?: () => void } | null>(null);
const loading = ref(false);
const isDark = useDark();
const turnstileTheme = computed<'light' | 'dark'>(() => (isDark.value ? 'dark' : 'light'));

const form = reactive({
  username: '',
  password: '',
  turnstileToken: ''
});

const rules = computed(() => ({
  username: [{ required: true, message: t('login.requiredUsername'), trigger: 'blur' }],
  password: [{ required: true, message: t('login.requiredPassword'), trigger: 'blur' }],
  turnstileToken: [{ required: true, message: t('login.requiredTurnstile'), trigger: 'change' }]
}));

const resetTurnstile = () => {
  form.turnstileToken = '';
  turnstileRef.value?.reset?.();
};

watch(turnstileTheme, () => {
  form.turnstileToken = '';
});

const handleLogin = async () => {
  if (!formRef.value) return;
  await formRef.value.validate(async (valid: boolean) => {
    if (valid) {
      loading.value = true;
      try {
        const { data } = await apiFetch<any>('/api/auth/login', {
          method: 'POST',
          body: {
            username: form.username,
            password: form.password,
            turnstileToken: form.turnstileToken
          }
        });

        authStore.setAuth(data.user, data.permissions);
        const displayName = data.user?.fullName || data.user?.username || form.username;
        ElMessage.success(t('login.welcome', { name: displayName }));
        navigateTo('/');
      } catch (err: any) {
        ElMessage.error(err.data?.statusMessage || t('login.failed'));
        resetTurnstile();
      } finally {
        loading.value = false;
      }
    }
  });
};
</script>
