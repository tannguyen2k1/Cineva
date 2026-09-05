<template>
  <el-card :class="[styles.card]" shadow="never">
    <template #header>
      <div :class="styles.header">
        <span>{{ t('dashboard.trafficTitle') }}</span>
        <span :class="styles.hint">{{ t('dashboard.trafficHint') }}</span>
      </div>
    </template>

    <el-skeleton v-if="loading" animated :rows="5" />
    <div v-else-if="!hasData" :class="styles.empty">
      {{ t('dashboard.trafficEmpty') }}
    </div>
    <div v-else :class="styles.chartWrap">
      <div :class="styles.legend">
        <span :class="styles.legViews">{{ t('dashboard.pageViews') }}</span>
        <span :class="styles.legVisitors">{{ t('dashboard.uniqueVisitors') }}</span>
        <span :class="styles.legLogins">{{ t('dashboard.logins') }}</span>
      </div>
      <svg :viewBox="`0 0 ${width} ${height}`" :class="styles.svg" role="img">
        <g v-for="(bar, i) in bars" :key="bar.date">
          <rect
            :x="bar.x"
            :y="bar.viewsY"
            :width="bar.barW"
            :height="bar.viewsH"
            rx="3"
            :class="styles.barViews"
          />
          <rect
            :x="bar.x + bar.barW + gapInner"
            :y="bar.visitorsY"
            :width="bar.barW"
            :height="bar.visitorsH"
            rx="3"
            :class="styles.barVisitors"
          />
          <rect
            :x="bar.x + (bar.barW + gapInner) * 2"
            :y="bar.loginsY"
            :width="bar.barW"
            :height="bar.loginsH"
            rx="3"
            :class="styles.barLogins"
          />
          <text :x="bar.labelX" :y="height - 8" :class="styles.axisLabel" text-anchor="middle">
            {{ bar.label }}
          </text>
        </g>
      </svg>
      <div :class="styles.totals">
        <div>
          <strong>{{ totalViews }}</strong>
          <span>{{ t('dashboard.pageViews') }}</span>
        </div>
        <div>
          <strong>{{ totalVisitors }}</strong>
          <span>{{ t('dashboard.uniqueVisitors') }}</span>
        </div>
        <div>
          <strong>{{ totalLogins }}</strong>
          <span>{{ t('dashboard.logins') }}</span>
        </div>
      </div>
    </div>
  </el-card>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import styles from './TrafficChart.module.scss'

export interface TrafficPoint {
  date: string
  pageViews: number
  uniqueVisitors: number
  logins: number
}

const props = withDefaults(defineProps<{
  loading?: boolean
  series?: TrafficPoint[] | null
}>(), {
  loading: false,
  series: () => []
})

const { t } = useI18n()

const width = 360
const height = 220
const padTop = 16
const padBottom = 28
const padX = 12
const gapInner = 3

const points = computed(() => props.series || [])
const hasData = computed(() => points.value.some((p) => p.pageViews || p.uniqueVisitors || p.logins))

const maxVal = computed(() => {
  let m = 1
  for (const p of points.value) {
    m = Math.max(m, p.pageViews || 0, p.uniqueVisitors || 0, p.logins || 0)
  }
  return m
})

const bars = computed(() => {
  const n = Math.max(points.value.length, 1)
  const groupW = (width - padX * 2) / n
  const barW = Math.max(4, (groupW - 10) / 3)
  const chartH = height - padTop - padBottom
  return points.value.map((p, i) => {
    const viewsH = ((p.pageViews || 0) / maxVal.value) * chartH
    const visitorsH = ((p.uniqueVisitors || 0) / maxVal.value) * chartH
    const loginsH = ((p.logins || 0) / maxVal.value) * chartH
    const x = padX + i * groupW + (groupW - (barW * 3 + gapInner * 2)) / 2
    const [, mo, day] = p.date.split('-')
    return {
      date: p.date,
      label: `${Number(day)}/${Number(mo)}`,
      x,
      barW,
      viewsH,
      visitorsH,
      loginsH,
      viewsY: padTop + chartH - viewsH,
      visitorsY: padTop + chartH - visitorsH,
      loginsY: padTop + chartH - loginsH,
      labelX: padX + i * groupW + groupW / 2
    }
  })
})

const totalViews = computed(() => points.value.reduce((s, p) => s + (p.pageViews || 0), 0))
const totalVisitors = computed(() => points.value.reduce((s, p) => s + (p.uniqueVisitors || 0), 0))
const totalLogins = computed(() => points.value.reduce((s, p) => s + (p.logins || 0), 0))
</script>
