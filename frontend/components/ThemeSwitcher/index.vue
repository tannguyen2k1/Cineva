<template>
  <el-switch
    v-model="isDark"
    inline-prompt
    :class="styles.switch"
    style="--el-switch-on-color: #334155; --el-switch-off-color: #3b82f6;"
    :active-icon="Moon"
    :inactive-icon="Sunny"
  />
</template>

<script setup lang="ts">
import { Sunny, Moon } from '@element-plus/icons-vue';
import { useDark } from '@vueuse/core';
import styles from './ThemeSwitcher.module.scss';

const isDark = useDark();
</script>
