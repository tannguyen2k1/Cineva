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

        <p :class="styles.formFooter">Bảo mật bởi Admin Pro</p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue';
import { useAuthStore } from '../stores/auth';
import { ElMessage } from 'element-plus';
import styles from './login.module.scss';

definePageMeta({
  layout: false
});

const authStore = useAuthStore();
const formRef = ref();
const loading = ref(false);

const form = reactive({
  tenant_id: 'default',
  username: '',
  password: ''
});

const rules = {
  tenant_id: [{ required: true, message: 'Vui lòng nhập Workspace', trigger: 'blur' }],
  username: [{ required: true, message: 'Vui lòng nhập tên đăng nhập', trigger: 'blur' }],
  password: [{ required: true, message: 'Vui lòng nhập mật khẩu', trigger: 'blur' }]
};

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
            password: form.password
          }
        });

        authStore.setAuth(data.token, data.user, data.tenant_id, data.permissions);
        ElMessage.success('Đăng nhập thành công!');
        navigateTo('/');
      } catch (err: any) {
        ElMessage.error(err.data?.statusMessage || 'Đăng nhập thất bại');
      } finally {
        loading.value = false;
      }
    }
  });
};
</script>
