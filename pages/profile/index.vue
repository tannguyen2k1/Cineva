<template>
  <div :class="styles.page">
    <div :class="styles.content">
      <section :class="styles.card">
        <div :class="styles.profileHeader">
          <el-upload
            action="#"
            :show-file-list="false"
            :auto-upload="false"
            :on-change="onPickAvatar"
            accept="image/jpeg,image/png,image/gif,image/webp"
            :disabled="avatarLoading"
            :class="styles.avatarUpload"
          >
            <div :class="styles.avatarHit">
              <el-avatar
                v-if="authStore.user?.avatar"
                :key="authStore.user.avatar"
                :size="96"
                :src="authStore.user.avatar"
              />
              <el-avatar v-else :size="96" :class="styles.avatarFallback">
                {{ authStore.user?.username?.charAt(0).toUpperCase() }}
              </el-avatar>
              <div :class="styles.avatarOverlay">
                <el-icon v-if="!avatarLoading"><Camera /></el-icon>
                <el-icon v-else class="is-loading"><Loading /></el-icon>
              </div>
            </div>
          </el-upload>

          <h2 :class="styles.name">
            {{ authStore.user?.fullName || authStore.user?.username }}
          </h2>
          <p :class="styles.handle">@{{ authStore.user?.username }}</p>
          <p v-if="form.email" :class="styles.email">{{ form.email }}</p>
        </div>
      </section>

      <el-alert
        v-if="successMessage"
        type="success"
        :title="successMessage"
        show-icon
        closable
        :class="styles.alert"
        @close="successMessage = ''"
      />
      <el-alert
        v-if="errorMessage"
        type="error"
        :title="errorMessage"
        show-icon
        closable
        :class="styles.alert"
        @close="errorMessage = ''"
      />

      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        label-position="top"
        @submit.prevent
      >
        <section :class="styles.card">
          <header :class="styles.cardHead">
            <h3 :class="styles.cardTitle">Thông tin cá nhân</h3>
            <p :class="styles.cardDesc">Cập nhật tên và email của bạn.</p>
          </header>

          <div :class="styles.cardBody">
            <el-form-item label="Tên đăng nhập" :class="styles.fullWidth">
              <el-input :model-value="authStore.user?.username" disabled />
            </el-form-item>

            <el-form-item label="Họ và tên" prop="fullName">
              <el-input v-model="form.fullName" placeholder="Nguyễn Văn A" />
            </el-form-item>

            <el-form-item label="Email" prop="email">
              <el-input v-model="form.email" placeholder="ban@congty.com" />
            </el-form-item>
          </div>

          <div :class="styles.sectionDivider">
            <h3 :class="styles.cardTitle">Đổi mật khẩu</h3>
            <p :class="styles.cardDesc">Để trống nếu không muốn thay đổi.</p>
          </div>

          <div :class="styles.cardBody">
            <el-form-item label="Mật khẩu mới" prop="password">
              <el-input
                v-model="form.password"
                type="password"
                placeholder="••••••••"
                show-password
                autocomplete="new-password"
              />
            </el-form-item>

            <el-form-item label="Xác nhận mật khẩu" prop="confirmPassword">
              <el-input
                v-model="form.confirmPassword"
                type="password"
                placeholder="••••••••"
                show-password
                autocomplete="new-password"
              />
            </el-form-item>
          </div>

          <footer :class="styles.cardFoot">
            <span :class="styles.footHint">Lưu toàn bộ thay đổi hồ sơ</span>
            <el-button type="primary" :loading="loading" @click="handleUpdate">
              Lưu thay đổi
            </el-button>
          </footer>
        </section>
      </el-form>
    </div>

    <AvatarCropDialog
      v-model="cropOpen"
      :file="cropFile"
      @confirm="uploadCroppedAvatar"
    />
  </div>
</template>

<script setup lang="ts">
import styles from './profile.module.scss';
import { ref, reactive, onMounted } from 'vue';
import { useAuthStore } from '~/stores/auth';
import { Camera, Loading } from '@element-plus/icons-vue';
import { ElMessage } from 'element-plus';
import type { FormInstance, FormRules } from 'element-plus';
import { withCacheBust } from '~/utils/avatar';
import AvatarCropDialog from '~/components/AvatarCropDialog/index.vue';

const authStore = useAuthStore();
const formRef = ref<FormInstance>();
const loading = ref(false);
const avatarLoading = ref(false);
const successMessage = ref('');
const errorMessage = ref('');

const cropOpen = ref(false);
const cropFile = ref<File | null>(null);

const form = reactive({
  fullName: '',
  email: '',
  password: '',
  confirmPassword: ''
});

onMounted(async () => {
  try {
    const headers: any = {};
    if (authStore.token) headers.Authorization = `Bearer ${authStore.token}`;

    const { data } = await $fetch<any>('/api/auth/me', { headers });
    if (data) {
      form.fullName = data.user.fullName || '';
      form.email = data.user.email || '';
    }
  } catch {
    form.fullName = authStore.user?.fullName || '';
    form.email = authStore.user?.email || '';
  }
});

const validatePass2 = (_rule: any, value: any, callback: any) => {
  if (form.password && value !== form.password) {
    callback(new Error('Mật khẩu xác nhận không khớp!'));
  } else {
    callback();
  }
};

const onPickAvatar = (uploadFile: any) => {
  if (!uploadFile?.raw) return;
  cropFile.value = uploadFile.raw as File;
  cropOpen.value = true;
};

const uploadCroppedAvatar = async (file: File) => {
  avatarLoading.value = true;
  try {
    const formData = new FormData();
    formData.append('file', file);

    const headers: Record<string, string> = {};
    if (authStore.token) headers.Authorization = `Bearer ${authStore.token}`;
    if (authStore.tenant_id) headers['x-tenant-id'] = authStore.tenant_id;

    const res = await $fetch<any>('/api/users/avatar', {
      method: 'POST',
      headers,
      body: formData
    });

    if (res.success && res.data.avatar) {
      if (authStore.user) {
        authStore.user.avatar = withCacheBust(res.data.avatar);
      }
      ElMessage.success('Cập nhật ảnh đại diện thành công');
    }
  } catch (error: any) {
    ElMessage.error(error.data?.statusMessage || error.message || 'Lỗi tải ảnh');
  } finally {
    avatarLoading.value = false;
    cropFile.value = null;
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
