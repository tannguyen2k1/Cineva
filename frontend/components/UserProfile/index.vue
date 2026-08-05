<template>
  <div :class="styles.userProfile" :style="{ gap: gap + 'px' }">
    <el-avatar v-if="avatar" :size="size" :src="avatar" />
    <el-avatar v-else :size="size" :style="{ backgroundColor: getAvatarColor(username) }">
      {{ username?.charAt(0).toUpperCase() }}
    </el-avatar>
    <span v-if="showName" :class="[styles.userName, textClass]">{{ fullName || username }}</span>
  </div>
</template>

<script setup lang="ts">
import styles from './UserProfile.module.scss';
import { computed } from 'vue';

const props = withDefaults(defineProps<{
  username: string;
  fullName?: string | null;
  avatar?: string | null;
  size?: 'small' | 'default' | 'large' | number;
  showName?: boolean;
  gap?: number;
  textClass?: string;
}>(), {
  fullName: '',
  avatar: '',
  size: 'default',
  showName: true,
  gap: 8,
  textClass: ''
});

// A simple hash function to generate consistent colors based on username
const getAvatarColor = (name: string) => {
  if (!name) return '#3b82f6';
  const colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#14b8a6'];
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  const index = Math.abs(hash) % colors.length;
  return colors[index];
};
</script>
