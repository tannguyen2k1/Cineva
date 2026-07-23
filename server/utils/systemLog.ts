import type { H3Event } from 'h3'
import { prisma } from './prisma'

export type SystemLogInput = {
  tenant_id: string
  user_id?: string | null
  action: string
  resource?: string | null
  details?: string | Record<string, unknown> | null
}

export function getActorUserId(event: H3Event): string | null {
  const user = event.context.user as { userId?: string } | undefined
  return user?.userId || null
}

/** Ghi nhật ký hệ thống — gọi trong từng API sau thao tác thành công */
export async function writeSystemLog(input: SystemLogInput) {
  const details =
    input.details == null
      ? null
      : typeof input.details === 'string'
        ? input.details
        : JSON.stringify(input.details)

  try {
    await prisma.systemLog.create({
      data: {
        tenant_id: input.tenant_id,
        user_id: input.user_id ?? null,
        action: input.action,
        resource: input.resource ?? null,
        details
      }
    })
  } catch (err) {
    // Không làm fail request chính nếu ghi log lỗi
    console.error('[systemLog]', err)
  }
}
