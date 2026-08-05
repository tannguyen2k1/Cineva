<template>
  <Teleport to="body">
    <div :class="styles.root">
      <Transition name="chat-panel">
        <div v-if="open" :class="styles.panel" role="dialog" :aria-label="t('chat.title')">
          <header :class="styles.panelHeader">
            <div>
              <h3 :class="styles.panelTitle">{{ t('chat.title') }}</h3>
              <p :class="styles.panelSubtitle">{{ t('chat.subtitle') }}</p>
            </div>
            <button
              type="button"
              :class="styles.iconBtn"
              :title="t('chat.close')"
              @click="open = false"
            >
              <el-icon :size="18"><Close /></el-icon>
            </button>
          </header>

          <div ref="listRef" :class="styles.messages">
            <p v-if="!messages.length" :class="styles.empty">{{ t('chat.empty') }}</p>
            <div
              v-for="msg in messages"
              :key="msg.id"
              :class="[styles.bubble, msg.role === 'user' ? styles.bubbleUser : styles.bubbleBot]"
            >
              {{ msg.text }}
            </div>
          </div>

          <form :class="styles.composer" @submit.prevent="send">
            <el-input
              v-model="draft"
              :placeholder="t('chat.placeholder')"
              clearable
              @keydown.enter.exact.prevent="send"
            />
            <el-button type="primary" :icon="Promotion" :disabled="!draft.trim()" native-type="submit" />
          </form>
        </div>
      </Transition>

      <button
        type="button"
        :class="[styles.fab, open ? styles.fabOpen : '']"
        :aria-label="open ? t('chat.close') : t('chat.open')"
        :title="open ? t('chat.close') : t('chat.open')"
        @click="open = !open"
      >
        <el-icon :size="24">
          <Close v-if="open" />
          <ChatDotRound v-else />
        </el-icon>
      </button>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { nextTick, ref, watch } from 'vue';
import { ChatDotRound, Close, Promotion } from '@element-plus/icons-vue';
import styles from './ChatWidget.module.scss';

interface ChatMessage {
  id: string;
  role: 'user' | 'bot';
  text: string;
}

const { t } = useI18n();
const open = ref(false);
const draft = ref('');
const listRef = ref<HTMLElement | null>(null);
const messages = ref<ChatMessage[]>([]);

const scrollToBottom = async () => {
  await nextTick();
  const el = listRef.value;
  if (el) el.scrollTop = el.scrollHeight;
};

watch(open, (value) => {
  if (value) scrollToBottom();
});

const send = async () => {
  const text = draft.value.trim();
  if (!text) return;

  messages.value.push({
    id: `${Date.now()}-u`,
    role: 'user',
    text
  });
  draft.value = '';
  await scrollToBottom();

  // UI shell — reply stub until a real chat API is wired
  window.setTimeout(async () => {
    messages.value.push({
      id: `${Date.now()}-b`,
      role: 'bot',
      text: t('chat.stubReply')
    });
    await scrollToBottom();
  }, 400);
};
</script>
