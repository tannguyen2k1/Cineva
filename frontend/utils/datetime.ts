/**
 * API datetimes are UTC (`...Z` or `...+00:00`).
 * Display always converts to the browser's local timezone.
 */

export function parseApiDate(value: string | Date | null | undefined): Date | null {
  if (value == null || value === '') return null
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value
  }

  const raw = String(value).trim()
  if (!raw) return null

  // Already has Z or numeric offset → trust native parse
  if (/[zZ]$/.test(raw) || /[+-]\d{2}:\d{2}$/.test(raw)) {
    const d = new Date(raw)
    return Number.isNaN(d.getTime()) ? null : d
  }

  // Naive ISO from API → treat as UTC (append Z)
  const normalized = raw.includes('T') ? `${raw}Z` : `${raw}T00:00:00Z`
  const d = new Date(normalized)
  return Number.isNaN(d.getTime()) ? null : d
}

export function formatApiDateTime(
  value: string | Date | null | undefined,
  locale: string,
  options?: Intl.DateTimeFormatOptions
): string {
  const d = parseApiDate(value)
  if (!d) return ''
  return d.toLocaleString(
    locale,
    options ?? {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    }
  )
}

export function formatApiDate(
  value: string | Date | null | undefined,
  locale: string,
  options?: Intl.DateTimeFormatOptions
): string {
  const d = parseApiDate(value)
  if (!d) return ''
  return d.toLocaleDateString(
    locale,
    options ?? { year: 'numeric', month: '2-digit', day: '2-digit' }
  )
}

/** Local calendar day `YYYY-MM-DD` → UTC ISO bounds for API filters. */
export function localDayStartToIso(day: string): string {
  return new Date(`${day}T00:00:00`).toISOString()
}

export function localDayEndToIso(day: string): string {
  return new Date(`${day}T23:59:59.999`).toISOString()
}
