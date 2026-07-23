<template>
  <div :class="styles.page">
    <section :class="styles.brand" aria-label="Admin Pro">
      <div :class="styles.brandMesh" aria-hidden="true" />
      <div :class="styles.brandGrid" aria-hidden="true" />
      <div :class="styles.brandContent">
        <h1 :class="styles.brandName">Admin Pro</h1>
        <p :class="styles.brandTagline">Quản trị đa workspace</p>
      </div>
    </section>

    <section :class="styles.formPanel">
      <div :class="styles.formInner">
        <header :class="styles.formHeader">
          <h2 :class="styles.formTitle">Đăng nhập</h2>
          <p :class="styles.formSubtitle">Nhập thông tin workspace để tiếp tục.</p>
        </header>

        <el-form
          ref="formRef"
          :class="styles.form"
          :model="form"
          :rules="rules"
          label-position="top"
          @submit.prevent
        >
          <el-form-item label="Workspace" prop="tenant_id">
            <el-input
              v-model="form.tenant_id"
              placeholder="VD: default"
              clearable
            />
          </el-form-item>

          <el-form-item label="Tên đăng nhập" prop="username">
            <el-input
              v-model="form.username"
              placeholder="Nhập tên đăng nhập"
              clearable
            />
          </el-form-item>

          <el-form-item label="Mật khẩu" prop="password">
            <el-input
              v-model="form.password"
              type="password"
              placeholder="Nhập mật khẩu"
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
              Đăng nhập
            </el-button>
          </el-form-item>
        </el-form>

        <p :class="styles.formFooter">Bảo mật bởi Admin Pro · Cloudflare Turnstile</p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch } from 'vue';
import { useAuthStore } from '../stores/auth';
import { ElMessage } from 'element-plus';
import { useDark } from '@vueuse/core';
import styles from './login.module.scss';

definePageMeta({
  layout: false
});

const authStore = useAuthStore();
const formRef = ref();
const turnstileRef = ref<{ reset?: () => void } | null>(null);
const loading = ref(false);
const isDark = useDark();
const turnstileTheme = computed<'light' | 'dark'>(() => (isDark.value ? 'dark' : 'light'));

const form = reactive({
  tenant_id: 'default',
  username: '',
  password: '',
  turnstileToken: ''
});

const rules = {
  tenant_id: [{ required: true, message: 'Vui lòng nhập Workspace', trigger: 'blur' }],
  username: [{ required: true, message: 'Vui lòng nhập tên đăng nhập', trigger: 'blur' }],
  password: [{ required: true, message: 'Vui lòng nhập mật khẩu', trigger: 'blur' }],
  turnstileToken: [{ required: true, message: 'Vui lòng xác minh bảo mật', trigger: 'change' }]
};

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
        const { data } = await $fetch('/api/auth/login', {
          method: 'POST',
          body: {
            tenant_id: form.tenant_id,
            username: form.username,
            password: form.password,
            turnstileToken: form.turnstileToken
          }
        });

        authStore.setAuth(data.token, data.user, data.tenant_id, data.permissions);
        const displayName = data.user?.fullName || data.user?.username || form.username;
        ElMessage.success(`Xin chào, ${displayName}!`);
        navigateTo('/');
      } catch (err: any) {
        ElMessage.error(err.data?.statusMessage || 'Đăng nhập thất bại');
        resetTurnstile();
      } finally {
        loading.value = false;
      }
    }
  });
};
</script>
