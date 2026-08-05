import {
  ref,
  watch,
  onMounted,
  onBeforeUnmount,
  nextTick,
  type Ref
} from 'vue'
import { PAGE_REFRESH_KEY, type PageRefreshApi } from './usePageRefresh'
import { inject } from 'vue'

type PtrOptions = {
  pullText: string
  releaseText: string
  refreshingText: string
}

const THRESHOLD = 56
const MAX_PULL = 88
/** Ignore tiny finger jitter before deciding pull vs scroll */
const DECIDE = 6

/**
 * True when any scrollable ancestor (including root) is not at the top.
 * Needed because some pages scroll an inner container, not #app-scroll.
 */
function isScrolledAwayFromTop(from: EventTarget | null, root: HTMLElement | null): boolean {
  let node: HTMLElement | null =
    from instanceof HTMLElement
      ? from
      : from instanceof Node
        ? from.parentElement
        : null

  while (node) {
    if (node.scrollTop > 1) return true
    if (root && node === root) break
    node = node.parentElement
  }

  if (root && root.scrollTop > 1) return true

  const doc = document.documentElement
  if (doc.scrollTop > 1 || document.body.scrollTop > 1) return true

  return false
}

/**
 * Pull-to-refresh for overflow scroll containers.
 *
 * Critical for smooth mid-list scrolling:
 * never keep a permanent non-passive touchmove on the scroller.
 * Attach it only for a gesture that started at scrollTop ≈ 0.
 */
export function usePullToRefresh(
  scrollEl: Ref<HTMLElement | null>,
  options: Ref<PtrOptions>,
  /** Pass from layout after providePageRefresh() — same-component inject is null in Vue */
  pageRefreshApi?: PageRefreshApi | null
) {
  const pageRefresh = pageRefreshApi ?? inject(PAGE_REFRESH_KEY, null)

  const refreshing = ref(false)
  const status = ref<'idle' | 'pulling' | 'ready' | 'refreshing'>('idle')
  const label = ref('')

  let startY = 0
  let armed = false
  let pulling = false
  let current = 0
  let raf = 0
  let moveBound = false
  let indicatorEl: HTMLElement | null = null
  let attached: HTMLElement | null = null

  const syncLabel = () => {
    const texts = options.value
    if (status.value === 'refreshing') label.value = texts.refreshingText
    else if (status.value === 'ready') label.value = texts.releaseText
    else if (status.value === 'pulling') label.value = texts.pullText
    else label.value = ''
  }

  const setIndicator = (distance: number, animate = false) => {
    if (!indicatorEl) {
      indicatorEl = scrollEl.value?.querySelector('[data-ptr-indicator]') as HTMLElement | null
    }
    if (!indicatorEl) return
    indicatorEl.style.transition = animate ? 'transform 0.2s ease, opacity 0.2s ease' : 'none'
    indicatorEl.style.transform = `translate3d(0, ${distance - MAX_PULL}px, 0)`
    indicatorEl.style.opacity = distance > 2 ? '1' : '0'
  }

  const unbindMove = () => {
    if (!attached || !moveBound) return
    attached.removeEventListener('touchmove', onTouchMove, true)
    moveBound = false
  }

  const bindMove = () => {
    if (!attached || moveBound) return
    attached.addEventListener('touchmove', onTouchMove, { passive: false, capture: true })
    moveBound = true
  }

  const reset = (animate = true) => {
    armed = false
    pulling = false
    current = 0
    unbindMove()
    if (!refreshing.value) {
      status.value = 'idle'
      syncLabel()
      setIndicator(0, animate)
    }
  }

  const onTouchStart = (e: TouchEvent) => {
    if (refreshing.value) return
    const el = scrollEl.value
    if (!el) return

    // Mid-list on #app-scroll OR any nested page scroller → ignore
    if (isScrolledAwayFromTop(e.target, el)) {
      reset(false)
      return
    }

    armed = true
    pulling = false
    startY = e.touches[0]?.clientY ?? 0
    current = 0
    // Only now may we need preventDefault — bind for this gesture only
    bindMove()
  }

  const onTouchMove = (e: TouchEvent) => {
    if (!armed || refreshing.value) return
    const el = scrollEl.value
    if (!el) return

    if (isScrolledAwayFromTop(e.target, el)) {
      reset(false)
      return
    }

    const y = e.touches[0]?.clientY ?? 0
    const delta = y - startY

    // Not decided yet: pull down vs scroll into content
    if (!pulling) {
      if (delta < -DECIDE) {
        // Scrolling into the list from the top — drop non-passive immediately
        reset(false)
        return
      }
      if (delta <= DECIDE) return
      pulling = true
    }

    // Confirmed pull-down from top
    if (e.cancelable) e.preventDefault()

    current = Math.min(MAX_PULL, delta * 0.5)

    if (raf) cancelAnimationFrame(raf)
    raf = requestAnimationFrame(() => {
      setIndicator(current, false)
      const next = current >= THRESHOLD ? 'ready' : 'pulling'
      if (status.value !== next) {
        status.value = next
        syncLabel()
      }
    })
  }

  const onTouchEnd = async () => {
    if (!armed && !pulling) {
      unbindMove()
      return
    }

    if (raf) {
      cancelAnimationFrame(raf)
      raf = 0
    }

    const shouldRefresh = pulling && current >= THRESHOLD && !refreshing.value
    unbindMove()
    armed = false
    pulling = false

    if (!shouldRefresh) {
      reset(true)
      return
    }

    refreshing.value = true
    status.value = 'refreshing'
    syncLabel()
    setIndicator(THRESHOLD, true)

    try {
      await pageRefresh?.run()
    } finally {
      refreshing.value = false
      reset(true)
    }
  }

  const detach = () => {
    if (!attached) return
    unbindMove()
    attached.removeEventListener('touchstart', onTouchStart)
    attached.removeEventListener('touchend', onTouchEnd)
    attached.removeEventListener('touchcancel', onTouchEnd)
    attached = null
    indicatorEl = null
  }

  const attach = async () => {
    await nextTick()
    const el = scrollEl.value
    if (!el || !import.meta.client) return
    if (attached === el) return

    detach()
    // start/end stay passive — never block native scroll by themselves
    el.addEventListener('touchstart', onTouchStart, { passive: true })
    el.addEventListener('touchend', onTouchEnd, { passive: true })
    el.addEventListener('touchcancel', onTouchEnd, { passive: true })
    attached = el
    indicatorEl = null
    setIndicator(0, false)
  }

  onMounted(() => {
    void attach()
  })

  watch(scrollEl, () => {
    void attach()
  })

  watch(options, () => syncLabel())

  onBeforeUnmount(() => {
    if (raf) cancelAnimationFrame(raf)
    detach()
  })

  return {
    refreshing,
    status,
    label,
    maxPull: MAX_PULL
  }
}
