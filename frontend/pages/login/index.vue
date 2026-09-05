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
          <h1>{{ t('login.title') }}</h1>
          <p>{{ t('login.subtitle') }}</p>
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
              autocomplete="username"
            />
          </el-form-item>

          <el-form-item :label="t('login.password')" prop="password">
            <el-input
              v-model="form.password"
              type="password"
              :placeholder="t('login.passwordPlaceholder')"
              show-password
              autocomplete="current-password"
              @keyup.enter="handleLogin"
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
              @click="handleLogin"
            >
              {{ t('login.submit') }}
            </el-button>
          </el-form-item>
        </el-form>

        <p :class="styles.meta">{{ t('login.footer') }}</p>
        <p :class="styles.meta">
          {{ t('login.noAccount') }}
          <NuxtLink to="/register" :class="styles.inlineLink">{{ t('login.goRegister') }}</NuxtLink>
        </p>
        <NuxtLink to="/" :class="styles.backHome">← {{ t('login.backHome') }}</NuxtLink>
      </section>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { ElMessage } from 'element-plus'
import type { User } from '~/stores/auth'
import styles from './login.module.scss'

definePageMeta({
  layout: false
})

const { t } = useI18n()
const authStore = useAuthStore()
const formRef = ref()
const turnstileRef = ref<{ reset?: () => void } | null>(null)
const loading = ref(false)

const form = reactive({
  username: '',
  password: '',
  turnstileToken: ''
})

const rules = computed(() => ({
  username: [{ required: true, message: t('login.requiredUsername'), trigger: 'blur' }],
  password: [{ required: true, message: t('login.requiredPassword'), trigger: 'blur' }],
  turnstileToken: [{ required: true, message: t('login.requiredTurnstile'), trigger: 'change' }]
}))

const resetTurnstile = () => {
  form.turnstileToken = ''
  turnstileRef.value?.reset?.()
}

const handleLogin = async () => {
  if (!formRef.value) return
  await formRef.value.validate(async (valid: boolean) => {
    if (!valid) return
    loading.value = true
    try {
      const res = await apiFetch<{
        success: boolean
        data: {
          user: User
          permissions: string[]
        }
      }>('/api/auth/login', {
        method: 'POST',
        body: {
          username: form.username,
          password: form.password,
          turnstileToken: form.turnstileToken
        }
      })

      const data = res.data
      authStore.setAuth(data.user, data.permissions)
      const displayName = data.user?.fullName || data.user?.username || form.username
      ElMessage.success(t('login.welcome', { name: displayName }))
      navigateTo('/')
    } catch (err: any) {
      ElMessage.error(err.data?.statusMessage || t('login.failed'))
      resetTurnstile()
    } finally {
      loading.value = false
    }
  })
}

useSeoMeta({
  title: () => `${t('login.title')} — ${t('app.name')}`
})
</script>
