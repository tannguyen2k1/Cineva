<template>
  <div class="login-container">
    <el-card class="login-card">
      <template #header>
        <div class="card-header">
          <h3>Login to Multi-Tenant App</h3>
        </div>
      </template>
      <el-form ref="formRef" :model="form" :rules="rules" label-width="120px" label-position="top">
        <el-form-item label="Tenant ID (Workspace)" prop="tenant_id">
          <el-input v-model="form.tenant_id" placeholder="VD: default" />
        </el-form-item>
        <el-form-item label="Username" prop="username">
          <el-input v-model="form.username" placeholder="Nhập username" />
        </el-form-item>
        <el-form-item label="Mật khẩu" prop="password">
          <el-input v-model="form.password" type="password" placeholder="Nhập mật khẩu" show-password @keyup.enter="handleLogin" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="loading" class="login-btn" @click="handleLogin">Đăng nhập</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue';
import { useAuthStore } from '../stores/auth';
import { ElMessage } from 'element-plus';

definePageMeta({
  layout: false // Không dùng dashboard layout
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
  tenant_id: [{ required: true, message: 'Vui lòng nhập Tenant ID', trigger: 'blur' }],
  username: [{ required: true, message: 'Vui lòng nhập Username', trigger: 'blur' }],
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
        
        // Sử dụng quyền thật trả về từ API và lưu UUID của tenant thay vì tên
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

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  background-color: #f0f2f5;
}
.login-card {
  width: 400px;
}
.card-header h3 {
  margin: 0;
  text-align: center;
  color: #303133;
}
.login-btn {
  width: 100%;
}
</style>
