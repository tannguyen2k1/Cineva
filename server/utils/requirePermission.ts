import type { H3Event } from 'h3'

/**
 * Throw 403 if the current user lacks the required permission.
 * Permissions are loaded by server/middleware/auth.ts into event.context.permissions.
 */
export function requirePermission(event: H3Event, permission: string) {
  const perms = event.context.permissions as Set<string> | undefined
  if (!perms || !perms.has(permission)) {
    throw createError({
      statusCode: 403,
      statusMessage: `Forbidden: requires "${permission}"`
    })
  }
}

/** Convenience: require any one of the listed permissions */
export function requireAnyPermission(event: H3Event, permissions: string[]) {
  const perms = event.context.permissions as Set<string> | undefined
  if (!perms || !permissions.some(p => perms.has(p))) {
    throw createError({
      statusCode: 403,
      statusMessage: `Forbidden: requires one of ${permissions.join(', ')}`
    })
  }
}
