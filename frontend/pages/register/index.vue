<template>
  <div :class="styles.page">
    <div :class="styles.bg" aria-hidden="true">
      <div :class="styles.bgGlow" />
      <div :class="styles.bgGrain" />
    </div>

    <header :class="styles.top">
      <NuxtLink to="/" :class="styles.brandLink" :title="t('app.name')">
        <img src="/brand/cineva-mark.svg" alt="" width="36" height="36" :class="styles.logo" />
        <span>
          <strong>{{ t('app.name') }}</strong>
          <small>{{ t('app.tagline') }}</small>
        </span>
      </NuxtLink>
    </header>

    <main :class="styles.main">
      <section :class="styles.card">
        <header :class="styles.cardHead">
          <h1>{{ t('register.title') }}</h1>
          <p>{{ t('register.subtitle') }}</p>
        </header>

        <el-form
          ref="formRef"
          :class="styles.form"
          :model="form"
          :rules="rules"
          label-position="top"
          @submit.prevent
        >
          <el-form-item :label="t('register.username')" prop="username">
            <el-input
              v-model="form.username"
              :placeholder="t('register.usernamePlaceholder')"
              clearable
              autocomplete="username"
            />
          </el-form-item>

          <el-form-item :label="t('register.fullName')" prop="fullName">
            <el-input
              v-model="form.fullName"
              :placeholder="t('register.fullNamePlaceholder')"
              clearable
              autocomplete="name"
            />
          </el-form-item>

          <el-form-item :label="t('register.email')" prop="email">
            <el-input
              v-model="form.email"
              :placeholder="t('register.emailPlaceholder')"
              clearable
              autocomplete="email"
            />
          </el-form-item>

          <el-form-item :label="t('register.password')" prop="password">
            <el-input
              v-model="form.password"
              type="password"
              :placeholder="t('register.passwordPlaceholder')"
              show-password
              autocomplete="new-password"
            />
          </el-form-item>

          <el-form-item :label="t('register.confirmPassword')" prop="confirmPassword">
            <el-input
              v-model="form.confirmPassword"
              type="password"
              :placeholder="t('register.confirmPasswordPlaceholder')"
              show-password
              autocomplete="new-password"
              @keyup.enter="handleRegister"
            />
          </el-form-item>

          <el-form-item prop="turnstileToken" :class="styles.turnstileItem">
            <div :class="styles.turnstileWrap">
              <NuxtTurnstile
                ref="turnstileRef"
                v-model="form.turnstileToken"
                :options="{ theme: 'dark', size: 'normal' }"
              />
            </div>
          </el-form-item>

          <el-form-item :class="styles.submitItem">
            <el-button
              :loading="loading"
              :class="styles.submitBtn"
              @click="handleRegister"
            >
              {{ t('register.submit') }}
            </el-button>
          </el-form-item>
        </el-form>

        <p :class="styles.meta">{{ t('register.footer') }}</p>
        <p :class="styles.meta">
          {{ t('register.hasAccount') }}
          <NuxtLink to="/login" :class="styles.inlineLink">{{ t('register.goLogin') }}</NuxtLink>
        </p>
        <NuxtLink to="/" :class="styles.backHome">← {{ t('login.backHome') }}</NuxtLink>
      </section>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import type { User } from '~/stores/auth'
import styles from '../login/login.module.scss'

definePageMeta({
  layout: false
})

const { t } = useI18n()
const authStore = useAuthStore()
const formRef = ref<FormInstance>()
const turnstileRef = ref<{ reset?: () => void } | null>(null)
const loading = ref(false)

const form = reactive({
  username: '',
  fullName: '',
  email: '',
  password: '',
  confirmPassword: '',
  turnstileToken: ''
})

const rules = computed<FormRules>(() => ({
  username: [
    { required: true, message: t('register.requiredUsername'), trigger: 'blur' },
    { min: 3, message: t('register.minUsername'), trigger: 'blur' }
  ],
  password: [
    { required: true, message: t('register.requiredPassword'), trigger: 'blur' },
    { min: 6, message: t('register.minPassword'), trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: t('register.requiredConfirm'), trigger: 'blur' },
    {
      validator: (_rule, value, callback) => {
        if (value !== form.password) {
          callback(new Error(t('register.passwordMismatch')))
          return
        }
        callback()
      },
      trigger: 'blur'
    }
  ],
  email: [
    {
      validator: (_rule, value, callback) => {
        if (!value) {
          callback()
          return
        }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value))) {
          callback(new Error(t('register.invalidEmail')))
          return
        }
        callback()
      },
      trigger: 'blur'
    }
  ],
  turnstileToken: [
    { required: true, message: t('login.requiredTurnstile'), trigger: 'change' }
  ]
}))

const resetTurnstile = () => {
  form.turnstileToken = ''
  turnstileRef.value?.reset?.()
}

const handleRegister = async () => {
  if (!formRef.value) return
  await formRef.value.validate(async (valid: boolean) => {
    if (!valid) return
    loading.value = true
    try {
      const body: Record<string, string> = {
        username: form.username.trim(),
        password: form.password,
        turnstileToken: form.turnstileToken
      }
      if (form.fullName.trim()) body.fullName = form.fullName.trim()
      if (form.email.trim()) body.email = form.email.trim()

      const res = await useApiFetch('/api/auth/register', {
        method: 'POST',
        body
      }) as {
        success: boolean
        data: {
          user: User
          permissions: string[]
        }
      }

      const data = res.data
      authStore.setAuth(data.user, data.permissions)
      const displayName = data.user?.fullName || data.user?.username || form.username
      ElMessage.success(t('register.welcome', { name: displayName }))
      navigateTo('/')
    } catch (err: any) {
      ElMessage.error(err?.data?.detail || err?.data?.statusMessage || t('register.failed'))
      resetTurnstile()
    } finally {
      loading.value = false
    }
  })
}

useSeoMeta({
  title: () => `${t('register.title')} — ${t('app.name')}`,
  robots: 'noindex, nofollow'
})
</script>
