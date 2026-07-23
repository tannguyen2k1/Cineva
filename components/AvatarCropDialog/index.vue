<template>
  <el-dialog
    :model-value="modelValue"
    title="Chọn vùng ảnh đại diện"
    width="560px"
    align-center
    destroy-on-close
    :close-on-click-modal="false"
    @update:model-value="emit('update:modelValue', $event)"
    @closed="onClosed"
  >
    <p :class="styles.hint">Kéo ảnh hoặc khung tròn để chọn vùng hiển thị.</p>

    <div :class="styles.cropperWrap">
      <Cropper
        v-if="imageSrc"
        :key="imageSrc"
        ref="cropperRef"
        :src="imageSrc"
        :stencil-component="CircleStencil"
        :stencil-props="{ aspectRatio: 1 }"
        :canvas="{ maxWidth: 1024, maxHeight: 1024 }"
        image-restriction="stencil"
        :class="styles.cropper"
      />
    </div>

    <template #footer>
      <el-button @click="close">Hủy</el-button>
      <el-button type="primary" :loading="confirming" @click="confirmCrop">
        Cắt & tải lên
      </el-button>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { Cropper, CircleStencil } from 'vue-advanced-cropper';
import 'vue-advanced-cropper/dist/style.css';
import { canvasToAvatarFile } from '~/utils/avatar';
import styles from './AvatarCropDialog.module.scss';
import { ElMessage } from 'element-plus';

const props = defineProps<{
  modelValue: boolean;
  file: File | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  confirm: [file: File];
}>();

const cropperRef = ref<InstanceType<typeof Cropper> | null>(null);
const imageSrc = ref('');
const confirming = ref(false);

watch(
  () => props.file,
  (file) => {
    if (imageSrc.value) {
      URL.revokeObjectURL(imageSrc.value);
      imageSrc.value = '';
    }
    if (file) {
      imageSrc.value = URL.createObjectURL(file);
    }
  },
  { immediate: true }
);

const close = () => emit('update:modelValue', false);

const onClosed = () => {
  if (imageSrc.value) {
    URL.revokeObjectURL(imageSrc.value);
    imageSrc.value = '';
  }
  confirming.value = false;
};

const confirmCrop = async () => {
  const cropper = cropperRef.value;
  if (!cropper) return;

  confirming.value = true;
  try {
    const { canvas } = cropper.getResult();
    if (!canvas) throw new Error('Không lấy được vùng cắt');

    const file = await canvasToAvatarFile(canvas, 512, 0.92);
    emit('confirm', file);
    close();
  } catch (err: any) {
    console.error(err);
    ElMessage.error(err?.message || 'Không thể cắt ảnh');
  } finally {
    confirming.value = false;
  }
};
</script>
