import {
  formatApiDate,
  formatApiDateTime,
  localDayEndToIso,
  localDayStartToIso,
  parseApiDate
} from '~/utils/datetime'

/**
 * Locale-aware formatting for API UTC timestamps → local display.
 */
export function useDateTime() {
  const { locale } = useI18n()

  const dateLocale = computed(() => (locale.value === 'en' ? 'en-US' : 'vi-VN'))

  const formatDateTime = (value: string | Date | null | undefined) =>
    formatApiDateTime(value, dateLocale.value)

  const formatDate = (value: string | Date | null | undefined) =>
    formatApiDate(value, dateLocale.value)

  return {
    dateLocale,
    parseApiDate,
    formatDate,
    formatDateTime,
    localDayStartToIso,
    localDayEndToIso
  }
}
