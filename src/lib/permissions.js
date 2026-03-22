export const PLATFORM_ROLE = Object.freeze({
  ADMIN: 'admin',
})

export const TEAM_ROLE = Object.freeze({
  CAPTAIN: 'captain',
  VICE_CAPTAIN: 'vice_captain',
  MEMBER: 'member',
})

export const MEMBERSHIP_STATUS = Object.freeze({
  ACTIVE: 'active',
  INVITED: 'invited',
  REMOVED: 'removed',
})

export const LEGACY_TEAM_ROLE_ALIASES = Object.freeze({
  admin: TEAM_ROLE.VICE_CAPTAIN,
})

export const TEAM_ROLE_LABELS = Object.freeze({
  [TEAM_ROLE.CAPTAIN]: 'Captain',
  [TEAM_ROLE.VICE_CAPTAIN]: 'Vice-captain',
  [TEAM_ROLE.MEMBER]: 'Member',
})

export const PROTECTED_ACTION = Object.freeze({
  DELETE_MATCH: 'delete_match',
  UNLOCK_MATCH: 'unlock_match',
  DELETE_FINE_ENTRY: 'delete_fine_entry',
  DELETE_FINE_TYPE: 'delete_fine_type',
  DELETE_SEASON: 'delete_season',
  REMOVE_TEAM_MEMBER: 'remove_team_member',
})

export const PROTECTED_ACTIONS = Object.freeze(Object.values(PROTECTED_ACTION))

export function normaliseTeamRole(role) {
  if (!role) return TEAM_ROLE.MEMBER
  return LEGACY_TEAM_ROLE_ALIASES[role] ?? role
}

export function isPlatformAdmin(platformRole) {
  return platformRole === PLATFORM_ROLE.ADMIN
}

export function getTeamRoleLabel(role) {
  return TEAM_ROLE_LABELS[normaliseTeamRole(role)] ?? TEAM_ROLE_LABELS[TEAM_ROLE.MEMBER]
}

export function hasActiveMembership(membership) {
  return membership?.status === MEMBERSHIP_STATUS.ACTIVE
}

export function canViewTeam({ membership, platformRole } = {}) {
  return isPlatformAdmin(platformRole) || hasActiveMembership(membership)
}

export function canManageTeamOperations({ membership, platformRole } = {}) {
  if (isPlatformAdmin(platformRole)) return true
  if (!hasActiveMembership(membership)) return false
  const role = normaliseTeamRole(membership.role)
  return role === TEAM_ROLE.CAPTAIN || role === TEAM_ROLE.VICE_CAPTAIN
}

export function canManageTeamRoles({ membership } = {}) {
  return hasActiveMembership(membership) && normaliseTeamRole(membership.role) === TEAM_ROLE.CAPTAIN
}

export function canAssignTeamRole({ actorMembership, targetRole } = {}) {
  if (!canManageTeamRoles({ membership: actorMembership })) return false
  return [TEAM_ROLE.VICE_CAPTAIN, TEAM_ROLE.MEMBER].includes(normaliseTeamRole(targetRole))
}

export function canEditPlayerProfileInTeam({ actorMembership, targetPlayerId, actorPlayerId, platformRole } = {}) {
  if (isPlatformAdmin(platformRole)) return true
  if (!hasActiveMembership(actorMembership)) return false
  if (targetPlayerId && actorPlayerId && targetPlayerId === actorPlayerId) return true
  return canManageTeamOperations({ membership: actorMembership })
}

export function canPerformProtectedAction({
  action,
  membership,
  platformRole,
  unlockCodeVerified = false,
} = {}) {
  if (!PROTECTED_ACTIONS.includes(action)) return false
  if (isPlatformAdmin(platformRole)) return false
  if (!hasActiveMembership(membership)) return false

  const role = normaliseTeamRole(membership.role)
  const hasTeamAuthority = role === TEAM_ROLE.CAPTAIN || role === TEAM_ROLE.VICE_CAPTAIN
  return hasTeamAuthority && unlockCodeVerified
}

export function assertPermission(condition, message) {
  if (!condition) throw new Error(message)
}
