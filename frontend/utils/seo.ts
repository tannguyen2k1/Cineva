/** Strip HTML and clamp description for meta tags */
export function seoPlainText(input: string | null | undefined, max = 160): string {
  if (!input) return ''
  const plain = input.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()
  if (plain.length <= max) return plain
  return `${plain.slice(0, max - 1).trim()}…`
}
