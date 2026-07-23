<template>
  <div :class="styles.pageContainer">
    <div :class="styles.pageHeader">
      <h2>Hồ sơ cá nhân</h2>
    </div>

    <el-row :gutter="20">
      <!-- Cột thông tin tĩnh -->
      <el-col :span="8">
        <div :class="[styles.premiumCard, styles.textCenter]">
          <el-avatar :size="100" style="background-color: var(--primary-color); font-size: 36px;">
            {{ authStore.user?.username?.charAt(0).toUpperCase() }}
          </el-avatar>
          <h3 style="margin-top: 16px; margin-bottom: 8px;">{{ authStore.user?.fullName || authStore.user?.username }}</h3>
          <p style="color: var(--text-secondary); margin-bottom: 24px;">@{{ authStore.user?.username }}</p>
          
          <el-divider />
          
          <div :class="styles.infoRow">
            <span :class="styles.label">ID Người dùng:</span>
            <span :class="styles.value">{{ authStore.user?.id || '...' }}</span>
          </div>
          <div :class="styles.infoRow">
            <span :class="styles.label">Tenant ID:</span>
            <span :class="styles.value">{{ authStore.tenant_id }}</span>
          </div>
        </div>
      </el-col>

      <!-- Cột Form chỉnh sửa -->
      <el-col :span="16">
        <div :class="styles.premiumCard">
          <h3 style="margin-top: 0; margin-bottom: 24px;">Cập nhật thông tin</h3>
          
          <el-alert v-if="successMessage" type="success" :title="successMessage" show-icon style="margin-bottom: 20px" />
          <el-alert v-if="errorMessage" type="error" :title="errorMessage" show-icon style="margin-bottom: 20px" />

          <el-form 
            ref="formRef" 
            :model="form" 
            :rules="rules" 
            label-position="top"
          >
            <el-form-item label="Tên đăng nhập (Username)">
              <el-input :model-value="authStore.user?.username" disabled />
              <div :class="styles.formHint">Tên đăng nhập không thể thay đổi.</div>
            </el-form-item>

            <el-form-item label="Họ và Tên (Full Name)" prop="fullName">
              <el-input v-model="form.fullName" placeholder="Nhập họ và tên..." />
            </el-form-item>

            <el-form-item label="Địa chỉ Email" prop="email">
              <el-input v-model="form.email" placeholder="Nhập email..." />
            </el-form-item>
            
            <el-divider />
            
            <h4 style="margin-top: 0; margin-bottom: 16px;">Đổi mật khẩu (Tùy chọn)</h4>
            
            <el-form-item label="Mật khẩu mới" prop="password">
              <el-input v-model="form.password" type="password" placeholder="Bỏ trống nếu không đổi..." show-password />
            </el-form-item>

            <el-form-item label="Xác nhận mật khẩu mới" prop="confirmPassword">
              <el-input v-model="form.confirmPassword" type="password" placeholder="Nhập lại mật khẩu mới..." show-password />
            </el-form-item>

            <el-form-item style="margin-top: 30px;">
              <el-button type="primary" @click="handleUpdate" :loading="loading">Lưu thay đổi</el-button>
            </el-form-item>
          </el-form>
        </div>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import styles from './profile.module.scss';
import { ref, reactive, onMounted } from 'vue';
import { useAuthStore } from '~/stores/auth';
import type { FormInstance, FormRules } from 'element-plus';

const authStore = useAuthStore();
const formRef = ref<FormInstance>();
const loading = ref(false);
const successMessage = ref('');
const errorMessage = ref('');

const form = reactive({
  fullName: '',
  email: '',
  password: '',
  confirmPassword: ''
});

// Load current user data into form
onMounted(async () => {
  // Lấy thông tin mới nhất từ API me
  try {
    const headers: any = {};
    if (authStore.token) headers.Authorization = `Bearer ${authStore.token}`;
    
    const { data } = await $fetch<any>('/api/auth/me', { headers });
    if (data) {
      form.fullName = data.user.fullName || '';
      form.email = data.user.email || '';
    }
  } catch (e) {
    // Fallback to store
    form.fullName = authStore.user?.fullName || '';
    form.email = authStore.user?.email || '';
  }
});

const validatePass2 = (rule: any, value: any, callback: any) => {
  if (value !== form.password) {
    callback(new Error('Mật khẩu xác nhận không khớp!'));
  } else {
    callback();
  }
};

const rules = reactive<FormRules>({
  email: [
    { type: 'email', message: 'Vui lòng nhập đúng định dạng email', trigger: ['blur', 'change'] }
  ],
  confirmPassword: [
    { validator: validatePass2, trigger: 'blur' }
  ]
});

const handleUpdate = async () => {
  if (!formRef.value) return;
  await formRef.value.validate(async (valid: boolean) => {
    if (valid) {
      loading.value = true;
      successMessage.value = '';
      errorMessage.value = '';
      
      try {
        const headers: any = {};
        if (authStore.token) headers.Authorization = `Bearer ${authStore.token}`;
        
        const payload: any = {
          fullName: form.fullName,
          email: form.email
        };
        
        if (form.password) {
          payload.password = form.password;
        }

        const res = await $fetch<any>('/api/users/profile', {
          method: 'PUT',
          headers,
          body: payload
        });

        successMessage.value = 'Cập nhật hồ sơ thành công!';
        form.password = '';
        form.confirmPassword = '';
        
        // Cập nhật lại Auth Store
        if (res.data && authStore.user) {
           authStore.user.fullName = res.data.fullName;
           authStore.user.email = res.data.email;
        }

      } catch (err: any) {
        errorMessage.value = err.data?.statusMessage || err.message || 'Lỗi khi cập nhật hồ sơ';
      } finally {
        loading.value = false;
      }
    }
  });
};
</script>
