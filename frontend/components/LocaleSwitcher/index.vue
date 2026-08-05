<template>
  <el-dropdown trigger="click" @command="onLocaleCommand">
    <button type="button" :class="styles.trigger" :title="t('header.language')">
      <span :class="styles.flag" aria-hidden="true">
        <svg v-if="locale === 'vi'" viewBox="0 0 30 20" xmlns="http://www.w3.org/2000/svg">
          <rect width="30" height="20" fill="#DA251D" />
          <polygon
            fill="#FF0"
            points="15,3.2 16.4,7.5 21,7.5 17.3,10.2 18.7,14.5 15,11.8 11.3,14.5 12.7,10.2 9,7.5 13.6,7.5"
          />
        </svg>
        <svg v-else viewBox="0 0 30 20" xmlns="http://www.w3.org/2000/svg">
          <rect width="30" height="20" fill="#B22234" />
          <rect y="1.54" width="30" height="1.54" fill="#fff" />
          <rect y="4.62" width="30" height="1.54" fill="#fff" />
          <rect y="7.69" width="30" height="1.54" fill="#fff" />
          <rect y="10.77" width="30" height="1.54" fill="#fff" />
          <rect y="13.85" width="30" height="1.54" fill="#fff" />
          <rect y="16.92" width="30" height="1.54" fill="#fff" />
          <rect width="12" height="10.77" fill="#3C3B6E" />
        </svg>
      </span>
      <el-icon :class="styles.chevron"><ArrowDown /></el-icon>
    </button>
    <template #dropdown>
      <el-dropdown-menu>
        <el-dropdown-item command="vi" :disabled="locale === 'vi'">
          <span :class="styles.option">
            <span :class="styles.flag" aria-hidden="true">
              <svg viewBox="0 0 30 20" xmlns="http://www.w3.org/2000/svg">
                <rect width="30" height="20" fill="#DA251D" />
                <polygon
                  fill="#FF0"
                  points="15,3.2 16.4,7.5 21,7.5 17.3,10.2 18.7,14.5 15,11.8 11.3,14.5 12.7,10.2 9,7.5 13.6,7.5"
                />
              </svg>
            </span>
            {{ t('lang.vi') }}
          </span>
        </el-dropdown-item>
        <el-dropdown-item command="en" :disabled="locale === 'en'">
          <span :class="styles.option">
            <span :class="styles.flag" aria-hidden="true">
              <svg viewBox="0 0 30 20" xmlns="http://www.w3.org/2000/svg">
                <rect width="30" height="20" fill="#B22234" />
                <rect y="1.54" width="30" height="1.54" fill="#fff" />
                <rect y="4.62" width="30" height="1.54" fill="#fff" />
                <rect y="7.69" width="30" height="1.54" fill="#fff" />
                <rect y="10.77" width="30" height="1.54" fill="#fff" />
                <rect y="13.85" width="30" height="1.54" fill="#fff" />
                <rect y="16.92" width="30" height="1.54" fill="#fff" />
                <rect width="12" height="10.77" fill="#3C3B6E" />
              </svg>
            </span>
            {{ t('lang.en') }}
          </span>
        </el-dropdown-item>
      </el-dropdown-menu>
    </template>
  </el-dropdown>
</template>

<script setup lang="ts">
import { ArrowDown } from '@element-plus/icons-vue';
import styles from './LocaleSwitcher.module.scss';

const { t, locale, setLocale } = useI18n();

const onLocaleCommand = async (code: string) => {
  if (code === 'vi' || code === 'en') {
    await setLocale(code);
  }
};
</script>
