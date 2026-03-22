import {
  TEAM_ROLE,
  PROTECTED_ACTION,
  PROTECTED_ACTIONS,
  canManageTeamOperations,
  canManageTeamRoles,
  canPerformProtectedAction,
  canViewTeam,
  isPlatformAdmin,
  normaliseTeamRole,
} from './permissions'

export const APP_ACTION = Object.freeze({
  VIEW_TEAM: 'view_team',
  MANAGE_PROFILE: 'manage_profile',
  CREATE_MATCH: 'create_match',
  EDIT_MATCH: 'edit_match',
  MANAGE_FINE_TYPES: 'manage_fine_types',
  MANAGE_SEASONS: 'manage_seasons',
  MANAGE_PAYMENTS: 'manage_payments',
  MANAGE_TEAM_OPERATIONS: 'manage_team_operations',
  MANAGE_TEAM_ROLES: 'manage_team_roles',
  MANAGE_UNLOCK_CODE: 'manage_unlock_code',
  ADMIN_RESET_UNLOCK_CODE: 'admin_reset_unlock_code',
  REMOVE_TEAM_MEMBER: 'remove_team_member',
  DELETE_MATCH: 'delete_match',
  DELETE_FINE_ENTRY: 'delete_fine_entry',
  DELETE_FINE_TYPE: 'delete_fine_type',
  DELETE_SEASON: 'delete_season',
  UNLOCK_MATCH: 'unlock_match',
})

export const ACTION_PROTECTED_MAP = Object.freeze({
  [APP_ACTION.DELETE_MATCH]: PROTECTED_ACTION.DELETE_MATCH,
  [APP_ACTION.DELETE_FINE_ENTRY]: PROTECTED_ACTION.DELETE_FINE_ENTRY,
  [APP_ACTION.DELETE_FINE_TYPE]: PROTECTED_ACTION.DELETE_FINE_TYPE,
  [APP_ACTION.DELETE_SEASON]: PROTECTED_ACTION.DELETE_SEASON,
  [APP_ACTION.REMOVE_TEAM_MEMBER]: PROTECTED_ACTION.REMOVE_TEAM_MEMBER,
  [APP_ACTION.UNLOCK_MATCH]: PROTECTED_ACTION.UNLOCK_MATCH,
})

export function getProtectedActionForAppAction(action) {
  return ACTION_PROTECTED_MAP[action] ?? null
}

export function isProtectedAppAction(action) {
  return Boolean(getProtectedActionForAppAction(action))
}

export function canAccessAction({ action, membership, platformRole, unlockCodeVerified = false } = {}) {
  const role = normaliseTeamRole(membership?.role)
  const isCaptain = role === TEAM_ROLE.CAPTAIN
  const isViceCaptain = role === TEAM_ROLE.VICE_CAPTAIN
  const canManageOps = canManageTeamOperations({ membership, platformRole })
  const isAdmin = isPlatformAdmin(platformRole)

  switch (action) {
    case APP_ACTION.VIEW_TEAM:
      return canViewTeam({ membership, platformRole })
    case APP_ACTION.MANAGE_PROFILE:
      return true
    case APP_ACTION.CREATE_MATCH:
    case APP_ACTION.EDIT_MATCH:
    case APP_ACTION.MANAGE_FINE_TYPES:
    case APP_ACTION.MANAGE_SEASONS:
    case APP_ACTION.MANAGE_PAYMENTS:
    case APP_ACTION.MANAGE_TEAM_OPERATIONS:
      return canManageOps
    case APP_ACTION.MANAGE_TEAM_ROLES:
      return canManageTeamRoles({ membership })
    case APP_ACTION.MANAGE_UNLOCK_CODE:
      return isCaptain
    case APP_ACTION.ADMIN_RESET_UNLOCK_CODE:
      return isAdmin
    default: {
      const protectedAction = getProtectedActionForAppAction(action)
      if (!protectedAction || !PROTECTED_ACTIONS.includes(protectedAction)) return false
      return canPerformProtectedAction({ action: protectedAction, membership, platformRole, unlockCodeVerified })
    }
  }
}

export function assertActionAccess({ action, membership, platformRole, unlockCodeVerified = false, message } = {}) {
  const allowed = canAccessAction({ action, membership, platformRole, unlockCodeVerified })
  if (!allowed) throw new Error(message || 'Forbidden')
  return true
}
