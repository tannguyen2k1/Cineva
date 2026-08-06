import { formatNumber as formatNumberLocale, parseNumber } from '~/utils/number'

/**
 * Locale-aware number display. Prefer this over `toLocaleString` in pages.
 * Fraction digits follow the value; override via Intl options when needed.
 */
export function useNumberFormat() {
  const { locale } = useI18n()

  const numberLocale = computed(() => (locale.value === 'en' ? 'en-US' : 'vi-VN'))

  const formatNumber = (
    value: number | string | null | undefined,
    options?: Intl.NumberFormatOptions
  ) => formatNumberLocale(value, numberLocale.value, options)

  return {
    numberLocale,
    parseNumber,
    formatNumber
  }
}
