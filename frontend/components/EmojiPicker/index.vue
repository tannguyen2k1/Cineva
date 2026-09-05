<template>
  <div ref="rootEl" :class="styles.root">
    <button
      type="button"
      :class="[styles.trigger, compact ? styles.compact : '']"
      :aria-label="t('cineva.pickEmoji')"
      :aria-expanded="open"
      @mouseenter="warm"
      @focus="warm"
      @click.stop="toggle"
    >
      😊
    </button>
    <ClientOnly>
      <div
        v-if="mounted"
        :class="[styles.panel, open ? styles.open : styles.closed]"
        :aria-hidden="!open"
        @click.stop
      >
        <EmojiMart
          :native="true"
          theme="dark"
          :hide-search="false"
          :display-recent="true"
          :hide-group-names="false"
          :disable-sticky-group-names="true"
          :static-texts="staticTexts"
          :group-names="groupNames"
          @select="onSelect"
        />
      </div>
    </ClientOnly>
  </div>
</template>

<script setup lang="ts">
import { nextTick } from 'vue'
import { onClickOutside } from '@vueuse/core'
import EmojiMart from 'vue3-emoji-picker'
import 'vue3-emoji-picker/css'
import styles from './EmojiPicker.module.scss'

withDefaults(
  defineProps<{
    compact?: boolean
  }>(),
  { compact: false }
)

const emit = defineEmits<{
  (e: 'pick', emoji: string): void
}>()

const { t } = useI18n()
const rootEl = ref<HTMLElement | null>(null)
const open = ref(false)
const mounted = ref(false)

const staticTexts = {
  placeholder: 'Tìm emoji...',
  skinTone: 'Màu da'
}

const groupNames = {
  recent: 'Gần đây',
  smileys_people: 'Mặt cười & Người',
  animals_nature: 'Động vật & Thiên nhiên',
  food_drink: 'Đồ ăn & Đồ uống',
  activities: 'Hoạt động',
  travel_places: 'Du lịch & Địa điểm',
  objects: 'Đồ vật',
  symbols: 'Biểu tượng',
  flags: 'Cờ'
}

onClickOutside(rootEl, () => {
  open.value = false
})

function warm() {
  if (!mounted.value) mounted.value = true
}

function toggle() {
  if (!mounted.value) {
    mounted.value = true
    // Let picker paint once closed, then open with transition
    nextTick(() => {
      requestAnimationFrame(() => {
        open.value = true
      })
    })
    return
  }
  open.value = !open.value
}

function onSelect(emoji: { i?: string }) {
  if (emoji?.i) emit('pick', emoji.i)
}
</script>
