<template>
  <el-card :class="[styles.card]" shadow="never">
    <div :class="styles.header">
      <span :class="styles.title">{{ title }}</span>
      <el-icon :class="[styles.icon, styles[`icon${iconTone}`]]">
        <component :is="icon" />
      </el-icon>
    </div>
    <div :class="styles.value">
      <el-skeleton v-if="loading" animated :rows="1" />
      <span v-else>{{ value }}</span>
    </div>
    <div :class="[styles.footer, styles[`tone${trendTone}`]]">
      <el-icon v-if="trendIcon"><component :is="trendIcon" /></el-icon>
      <span>{{ trendText }}</span>
    </div>
  </el-card>
</template>

<script setup lang="ts">
import type { Component } from 'vue';
import styles from './StatCard.module.scss';

withDefaults(defineProps<{
  title: string;
  value: string | number;
  loading?: boolean;
  icon: Component;
  iconTone?: 'Blue' | 'Green' | 'Amber' | 'Red';
  trendText: string;
  trendTone?: 'Success' | 'Warning' | 'Danger';
  trendIcon?: Component;
}>(), {
  loading: false,
  iconTone: 'Blue',
  trendTone: 'Success'
});
</script>
