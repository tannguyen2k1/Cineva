/**
 * Display numbers via Intl — never ad-hoc separators / toFixed in pages.
 * Locale comes from i18n (`vi` → vi-VN, `en` → en-US).
 */

export type NumberInput = number | string | null | undefined

export function parseNumber(value: NumberInput): number | null {
  if (value == null || value === '') return null
  const n = typeof value === 'number' ? value : Number(String(value).trim())
  return Number.isFinite(n) ? n : null
}

/** Fraction digit count from the input as given (JS number drops trailing zeros). */
export function fractionDigitsOf(value: NumberInput): number {
  if (value == null || value === '') return 0

  const raw = String(value).trim()
  if (!raw || /e/i.test(raw)) return 0

  const dot = raw.indexOf('.')
  return dot === -1 ? 0 : raw.length - dot - 1
}

/**
 * Format a number for UI. Keeps the input's fraction digits by default;
 * pass Intl options when you need a fixed scale (e.g. 2 decimals).
 */
export function formatNumber(
  value: NumberInput,
  locale: string,
  options?: Intl.NumberFormatOptions
): string {
  const n = parseNumber(value)
  if (n == null) return ''

  const digits = fractionDigitsOf(value)
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
    ...options
  }).format(n)
}
