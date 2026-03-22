import { supabase } from './supabase'

function sanitize(value) {
  if (value == null) return null
  if (Array.isArray(value)) return value.map(sanitize).filter(item => item !== undefined)
  if (typeof value === 'object') {
    return Object.entries(value).reduce((acc, [key, entry]) => {
      const lowerKey = key.toLowerCase()
      if (lowerKey.includes('unlockcode') || lowerKey.includes('code') || lowerKey.includes('token') || lowerKey.includes('secret') || lowerKey.includes('otp') || lowerKey.includes('password') || lowerKey.includes('hash') || lowerKey.includes('salt')) {
        return acc
      }
      const sanitized = sanitize(entry)
      if (sanitized !== undefined) acc[key] = sanitized
      return acc
    }, {})
  }
  if (typeof value === 'string') return value.slice(0, 500)
  return value
}

export const AUDIT_ACTION = Object.freeze({
  UNLOCK_CODE_SET: 'unlock_code.set',
  UNLOCK_CODE_CHANGED: 'unlock_code.changed',
  UNLOCK_CODE_RESET_REQUESTED_BY_CAPTAIN: 'unlock_code.reset_requested_by_captain',
  UNLOCK_CODE_RESET_TRIGGERED_BY_PLATFORM_ADMIN: 'unlock_code.reset_triggered_by_platform_admin',
  UNLOCK_CODE_VERIFICATION: 'unlock_code.verification',
  TEAM_ROLE_CHANGED: 'team.role_changed',
  TEAM_CAPTAIN_CHANGED: 'team.captain_assignment_changed',
  TEAM_MEMBERSHIP_REMOVED: 'team.membership_removed',
  PROTECTED_RECORD_DELETED: 'protected_record.deleted',
  PROTECTED_RECORD_REVERSED: 'protected_record.reversed',
})

export async function logAuditEvent({
  action,
  teamId,
  actorMembership = null,
  platformRole = null,
  targetEntityType = null,
  targetEntityId = null,
  outcome = 'success',
  payload = null,
}) {
  if (!action || !teamId) return null

  const insertPayload = {
    team_id: teamId,
    action,
    outcome,
    actor_role_context: sanitize({
      teamRole: actorMembership?.role ?? null,
      membershipStatus: actorMembership?.status ?? null,
      membershipId: actorMembership?.id ?? null,
      playerId: actorMembership?.playerId ?? null,
      platformRole,
    }),
    target_entity_type: targetEntityType,
    target_entity_id: targetEntityId,
    payload: sanitize(payload),
  }

  const result = await supabase.from('audit_logs').insert(insertPayload).select('id').single()
  if (result.error) throw result.error
  return result.data
}

export async function logAuditEventSafely(event) {
  try {
    return await logAuditEvent(event)
  } catch (error) {
    console.warn('Audit log write failed:', error)
    return null
  }
}
