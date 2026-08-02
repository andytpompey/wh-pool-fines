import { supabase } from './supabase'
import { TEAM_ROLE, getTeamRoleLabel, normaliseTeamRole, PROTECTED_ACTIONS, PROTECTED_ACTION, PLATFORM_ROLE } from './permissions'
import { APP_ACTION, assertActionAccess, canAccessAction, getProtectedActionForAppAction } from './accessControl'
import * as auth from './auth'
import { AUDIT_ACTION, logAuditEventSafely } from './audit'

function handle(result) {
  if (result.error) throw result.error
  return result.data
}

export const ROLE_LABELS = {
  [TEAM_ROLE.CAPTAIN]: getTeamRoleLabel(TEAM_ROLE.CAPTAIN),
  [TEAM_ROLE.VICE_CAPTAIN]: getTeamRoleLabel(TEAM_ROLE.VICE_CAPTAIN),
  [TEAM_ROLE.MEMBER]: getTeamRoleLabel(TEAM_ROLE.MEMBER),
}

export { PROTECTED_ACTION, PROTECTED_ACTIONS }

export function getRoleLabel(role) {
  return getTeamRoleLabel(role)
}

export function canManageTeam(role, platformRole = null) {
  return canAccessAction({ action: APP_ACTION.MANAGE_TEAM_OPERATIONS, membership: { role: normaliseTeamRole(role), status: 'active' }, platformRole })
}

export function canCaptainManageRoles(role) {
  return canAccessAction({ action: APP_ACTION.MANAGE_TEAM_ROLES, membership: { role: normaliseTeamRole(role), status: 'active' } })
}

export async function createTeam({ name, createdBy, joinCode = null }) {
  void createdBy
  return handle(await supabase.rpc('create_team_with_captain', {
    team_name: name,
    requested_join_code: joinCode,
  }))
}

export async function getTeamById(teamId) {
  if (!teamId) return null
  const row = handle(await supabase
    .from('teams')
    .select('id, name, join_code, created_by, created_at, unlock_code_last_rotated_at, unlock_code_reset_required, unlock_code_reset_requested_at, subs_enabled, drivers_void_subs, sub_amount, logo_url, rackem_import_enabled, rackem_league_slug, rackem_league_name, rackem_team_id, rackem_team_name, rackem_team_url')
    .eq('id', teamId)
    .maybeSingle())
  return row ?? null
}

export async function getTeamByJoinCode(joinCode) {
  if (!joinCode) return null
  const row = handle(await supabase
    .from('teams')
    .select('id, name, join_code, created_by, created_at')
    .eq('join_code', joinCode.trim().toUpperCase())
    .maybeSingle())
  return row ?? null
}

export async function joinTeamByCode(joinCode) {
  if (!joinCode) throw new Error('Join code is required.')
  return handle(await supabase.rpc('join_team_by_code', {
    requested_join_code: joinCode.trim().toUpperCase(),
  }))
}

export async function addTeamMembership({ teamId, playerId, role = TEAM_ROLE.MEMBER, status = 'active' }) {
  return handle(await supabase
    .from('team_memberships')
    .upsert(
      { team_id: teamId, player_id: playerId, role: normaliseTeamRole(role), status },
      { onConflict: 'team_id,player_id' },
    )
    .select('*')
    .single())
}

export async function updateTeamMembership({ membershipId, role, status }) {
  if (!membershipId) throw new Error('Membership is required.')
  const payload = {}
  if (role) payload.role = normaliseTeamRole(role)
  if (status) payload.status = status
  return handle(await supabase
    .from('team_memberships')
    .update(payload)
    .eq('id', membershipId)
    .select('*')
    .single())
}

export async function changeTeamMemberRole({ membershipId, nextRole, actorMembership, teamId, targetPlayerId = null, previousRole = null }) {
  const updated = await updateTeamMembership({ membershipId, role: nextRole })
  await logAuditEventSafely({
    action: AUDIT_ACTION.TEAM_ROLE_CHANGED,
    teamId,
    actorMembership,
    outcome: 'success',
    targetEntityType: 'team_membership',
    targetEntityId: membershipId,
    payload: { targetPlayerId, previousRole, nextRole },
  })
  return updated
}

export async function transferCaptaincy({ teamId, actorMembership, incomingCaptainMembershipId, outgoingCaptainMembershipId, incomingCaptainPlayerId = null }) {
  void actorMembership
  void incomingCaptainPlayerId
  if (!outgoingCaptainMembershipId) throw new Error('Current captain membership is required.')
  return handle(await supabase.rpc('transfer_team_captain', {
    operation_id: crypto.randomUUID(),
    target_team_id: teamId,
    incoming_membership_id: incomingCaptainMembershipId,
    outgoing_membership_id: outgoingCaptainMembershipId,
  }))
}

export async function removeTeamMember({ membershipId, actorMembership, teamId, targetPlayerId = null, previousRole = null }) {
  const updated = await updateTeamMembership({ membershipId, status: 'removed' })
  await logAuditEventSafely({
    action: AUDIT_ACTION.TEAM_MEMBERSHIP_REMOVED,
    teamId,
    actorMembership,
    outcome: 'success',
    targetEntityType: 'team_membership',
    targetEntityId: membershipId,
    payload: { targetPlayerId, previousRole, nextStatus: 'removed' },
  })
  return updated
}

export async function getTeamMembership({ teamId, playerId }) {
  if (!teamId || !playerId) return null
  const row = handle(await supabase
    .from('team_memberships')
    .select('*')
    .eq('team_id', teamId)
    .eq('player_id', playerId)
    .limit(1)
    .maybeSingle())
  return row ? { ...row, role: normaliseTeamRole(row.role) } : null
}

export async function listTeamMemberships(teamId) {
  const rows = handle(await supabase
    .from('team_memberships')
    .select('*')
    .eq('team_id', teamId)
    .order('joined_at'))

  return (rows ?? []).map(row => ({ ...row, role: normaliseTeamRole(row.role) }))
}

export async function listPendingTeamInvites(teamId) {
  if (!teamId) return []
  return handle(await supabase
    .from('team_invites')
    .select('*')
    .eq('team_id', teamId)
    .eq('status', 'pending')
    .order('created_at', { ascending: false }))
}

export async function createTeamInvite({ teamId, email, token, playerId = null, invitedByPlayerId = null, expiresAt = null }) {
  return handle(await supabase
    .from('team_invites')
    .insert({
      team_id: teamId,
      email: email.trim().toLowerCase(),
      token,
      player_id: playerId,
      invited_by_player_id: invitedByPlayerId,
      expires_at: expiresAt,
    })
    .select('*')
    .single())
}

export async function upsertPendingTeamInvite({ teamId, email, token, playerId = null, invitedByPlayerId = null, expiresAt = null }) {
  const normalizedEmail = email?.trim().toLowerCase()
  if (!teamId) throw new Error('Team is required.')
  if (!normalizedEmail) throw new Error('Email is required.')

  const existing = handle(await supabase
    .from('team_invites')
    .select('*')
    .eq('team_id', teamId)
    .ilike('email', normalizedEmail)
    .eq('status', 'pending')
    .limit(1)
    .maybeSingle())

  if (existing) {
    return handle(await supabase
      .from('team_invites')
      .update({
        email: normalizedEmail,
        token,
        player_id: playerId,
        invited_by_player_id: invitedByPlayerId,
        expires_at: expiresAt,
      })
      .eq('id', existing.id)
      .select('*')
      .single())
  }

  return createTeamInvite({ teamId, email: normalizedEmail, token, playerId, invitedByPlayerId, expiresAt })
}

export async function acceptTeamInvite({ teamId, email, playerId = null }) {
  const normalizedEmail = email?.trim().toLowerCase()
  if (!teamId || !normalizedEmail) return null

  const existing = handle(await supabase
    .from('team_invites')
    .select('*')
    .eq('team_id', teamId)
    .ilike('email', normalizedEmail)
    .eq('status', 'pending')
    .limit(1)
    .maybeSingle())

  if (!existing) return null

  return handle(await supabase
    .from('team_invites')
    .update({
      status: 'accepted',
      player_id: playerId ?? existing.player_id,
    })
    .eq('id', existing.id)
    .select('*')
    .single())
}

export async function updateTeamInvite({ inviteId, status, token, playerId = null, invitedByPlayerId = null, expiresAt = null }) {
  if (!inviteId) throw new Error('Invite is required.')
  const payload = {}
  if (status) payload.status = status
  if (token) payload.token = token
  if (playerId !== null) payload.player_id = playerId
  if (invitedByPlayerId !== null) payload.invited_by_player_id = invitedByPlayerId
  if (expiresAt !== null) payload.expires_at = expiresAt

  return handle(await supabase
    .from('team_invites')
    .update(payload)
    .eq('id', inviteId)
    .select('*')
    .single())
}

export async function getPendingInviteByToken(token) {
  if (!token) return null
  const row = handle(await supabase
    .from('team_invites')
    .select('*')
    .eq('token', token)
    .eq('status', 'pending')
    .maybeSingle())
  return row ?? null
}

export async function acceptInviteByToken(token) {
  if (!token) throw new Error('Invitation token is required.')
  return handle(await supabase.rpc('accept_team_invite_by_token', { invite_token: token }))
}

async function updateTeamUnlockCodeRecord({ teamId, unlockCode, resetRequired = false }) {
  if (!teamId) throw new Error('Team is required.')
  if (resetRequired) throw new Error('Unlock-code recovery must be completed by the server recovery flow.')
  return handle(await supabase.rpc('set_team_unlock_code', {
    target_team_id: teamId,
    new_unlock_code: unlockCode,
  }))
}

export async function setTeamUnlockCode({ teamId, unlockCode, actorMembership }) {
  assertActionAccess({ action: APP_ACTION.MANAGE_UNLOCK_CODE, membership: actorMembership, message: 'Only captains can set a team unlock code.' })
  const existingTeam = await getTeamById(teamId)
  if (existingTeam?.unlock_code_reset_required === false && existingTeam?.unlock_code_last_rotated_at) {
    throw new Error('Unlock code already exists. Use change unlock code instead.')
  }
  const updatedTeam = await updateTeamUnlockCodeRecord({ teamId, unlockCode, resetRequired: false })
  await logAuditEventSafely({
    action: AUDIT_ACTION.UNLOCK_CODE_SET,
    teamId,
    actorMembership,
    outcome: 'success',
    targetEntityType: 'team',
    targetEntityId: teamId,
  })
  return updatedTeam
}

export async function changeTeamUnlockCode({ teamId, currentUnlockCode, nextUnlockCode, actorMembership }) {
  assertActionAccess({ action: APP_ACTION.MANAGE_UNLOCK_CODE, membership: actorMembership, message: 'Only captains can change a team unlock code.' })
  const currentValid = await verifyTeamUnlockCode({
    teamId,
    unlockCode: currentUnlockCode,
    actorMembership,
    action: AUDIT_ACTION.UNLOCK_CODE_CHANGED,
    targetEntityId: 'change_unlock_code',
  })
  if (!currentValid) throw new Error('Current unlock code is incorrect.')
  const updatedTeam = await updateTeamUnlockCodeRecord({ teamId, unlockCode: nextUnlockCode, resetRequired: false })
  await logAuditEventSafely({
    action: AUDIT_ACTION.UNLOCK_CODE_CHANGED,
    teamId,
    actorMembership,
    outcome: 'success',
    targetEntityType: 'team',
    targetEntityId: teamId,
  })
  return updatedTeam
}

export async function verifyTeamUnlockCode({ teamId, unlockCode, actorMembership = null, platformRole = null, action = AUDIT_ACTION.UNLOCK_CODE_VERIFICATION, targetEntityType = 'team', targetEntityId = null } = {}) {
  if (!teamId || !unlockCode?.trim()) return false
  void actorMembership
  void platformRole
  void targetEntityType
  const protectedAction = targetEntityId ?? action
  const result = handle(await supabase.rpc('verify_team_unlock_code', {
    target_team_id: teamId,
    protected_action: protectedAction,
    supplied_unlock_code: unlockCode.trim(),
  }))
  return result?.authorized ? result : false
}

export async function requestCaptainUnlockCodeReset({ teamId, actorMembership, verificationMethod, verificationTarget, otpToken, captainContacts = [], teamName }) {
  assertActionAccess({ action: APP_ACTION.MANAGE_UNLOCK_CODE, membership: actorMembership, message: 'Only captains can request an unlock code reset.' })
  void captainContacts
  void teamName
  const verification = verificationMethod === 'whatsapp'
    ? await auth.verifyWhatsAppOtp(verificationTarget, otpToken)
    : await auth.verifyEmailOtp(verificationTarget, otpToken)
  if (!verification?.session) throw new Error('Recent identity verification is required.')
  const result = handle(await supabase.functions.invoke('team-communications', {
    body: { action: 'reset-unlock-code', teamId, reason: 'captain_recovery' },
  }))
  return { success: true, notification: result }
}

export async function triggerAdminUnlockCodeReset({ teamId, platformRole, actorMembership = null, captainContacts = [], teamName }) {
  assertActionAccess({ action: APP_ACTION.ADMIN_RESET_UNLOCK_CODE, platformRole, message: 'Only platform admins can trigger team unlock code resets.' })
  void actorMembership
  void captainContacts
  void teamName
  const result = handle(await supabase.functions.invoke('team-communications', {
    body: { action: 'reset-unlock-code', teamId, reason: 'platform_admin_reset' },
  }))
  return { success: true, notification: result }
}

export async function markTeamUnlockCodeResetRequired(teamId) {
  if (!teamId) throw new Error('Team is required.')
  return handle(await supabase.rpc('mark_team_unlock_reset_required', {
    target_team_id: teamId,
  }))
}


function getAppActionForProtectedAction(action) {
  return Object.values(APP_ACTION).find(candidate => getProtectedActionForAppAction(candidate) === action) ?? null
}

export async function canActorPerformProtectedAction({ action, membership, platformRole, teamId, unlockCode }) {
  if (!PROTECTED_ACTIONS.includes(action)) return false
  const authorization = await verifyTeamUnlockCode({ teamId, unlockCode, actorMembership: membership, platformRole, action: AUDIT_ACTION.UNLOCK_CODE_VERIFICATION, targetEntityType: 'protected_action', targetEntityId: action })
  return canAccessAction({ action: getAppActionForProtectedAction(action), membership, platformRole, unlockCodeVerified: Boolean(authorization) })
    ? authorization
    : false
}

export async function assertProtectedActionAccess({ action, membership, platformRole, teamId, unlockCode, message = 'Forbidden' }) {
  const protectedAction = getProtectedActionForAppAction(action) ?? action
  if (!PROTECTED_ACTIONS.includes(protectedAction)) throw new Error('Unsupported protected action.')
  const authorization = await verifyTeamUnlockCode({ teamId, unlockCode, actorMembership: membership, platformRole, action: AUDIT_ACTION.UNLOCK_CODE_VERIFICATION, targetEntityType: 'protected_action', targetEntityId: protectedAction })
  const appAction = getProtectedActionForAppAction(action) ? action : getAppActionForProtectedAction(protectedAction)
  assertActionAccess({ action: appAction, membership, platformRole, unlockCodeVerified: Boolean(authorization), message })
  return authorization.grantToken
}

const normaliseMembership = row => ({
  id: row.id,
  role: normaliseTeamRole(row.role),
  status: row.status,
  joinedAt: row.joined_at,
  team: row.teams ? {
    id: row.teams.id,
    name: row.teams.name,
    joinCode: row.teams.join_code,
    createdAt: row.teams.created_at,
    unlockCodeResetRequired: Boolean(row.teams.unlock_code_reset_required),
    unlockCodeLastRotatedAt: row.teams.unlock_code_last_rotated_at,
    subsEnabled: row.teams.subs_enabled !== false,
    driversVoidSubs: row.teams.drivers_void_subs !== false,
    subAmount: Number(row.teams.sub_amount ?? 0.50),
    logoUrl: row.teams.logo_url ?? '',
    rackemImportEnabled: Boolean(row.teams.rackem_import_enabled),
    rackemLeagueSlug: row.teams.rackem_league_slug ?? '',
    rackemLeagueName: row.teams.rackem_league_name ?? '',
    rackemTeamId: row.teams.rackem_team_id ?? '',
    rackemTeamName: row.teams.rackem_team_name ?? '',
    rackemTeamUrl: row.teams.rackem_team_url ?? '',
  } : null,
})

export async function listMembershipsForPlayer(playerId) {
  if (!playerId) return []
  const rows = handle(await supabase
    .from('team_memberships')
    .select('id, role, status, joined_at, teams ( id, name, join_code, created_at, unlock_code_reset_required, unlock_code_last_rotated_at, subs_enabled, drivers_void_subs, sub_amount, logo_url, rackem_import_enabled, rackem_league_slug, rackem_league_name, rackem_team_id, rackem_team_name, rackem_team_url )')
    .eq('player_id', playerId)
    .eq('status', 'active')
    .order('joined_at'))

  return (rows ?? []).map(normaliseMembership).filter(membership => membership.team)
}

export async function updateTeamSettings({
  teamId,
  subsEnabled,
  driversVoidSubs,
  subAmount,
  logoUrl,
  rackemImportEnabled,
  rackemLeagueSlug,
  rackemLeagueName,
  rackemTeamId,
  rackemTeamName,
  rackemTeamUrl,
  actorMembership,
  platformRole,
}) {
  if (!teamId) throw new Error('Team is required.')
  assertActionAccess({
    action: APP_ACTION.MANAGE_TEAM_OPERATIONS,
    membership: actorMembership,
    platformRole,
    message: 'Only captains and vice-captains can update team settings.',
  })

  return handle(await supabase
    .from('teams')
    .update({
      subs_enabled: Boolean(subsEnabled),
      drivers_void_subs: Boolean(subsEnabled) && Boolean(driversVoidSubs),
      sub_amount: Number(subAmount),
      logo_url: logoUrl || null,
      rackem_import_enabled: Boolean(rackemImportEnabled),
      rackem_league_slug: rackemImportEnabled ? rackemLeagueSlug || null : null,
      rackem_league_name: rackemImportEnabled ? rackemLeagueName || null : null,
      rackem_team_id: rackemImportEnabled ? rackemTeamId || null : null,
      rackem_team_name: rackemImportEnabled ? rackemTeamName || null : null,
      rackem_team_url: rackemImportEnabled ? rackemTeamUrl || null : null,
    })
    .eq('id', teamId)
    .select('*')
    .single())
}

export async function getTeamMembershipCount(teamId) {
  if (!teamId) return 0
  const { count, error } = await supabase
    .from('team_memberships')
    .select('*', { count: 'exact', head: true })
    .eq('team_id', teamId)
    .eq('status', 'active')

  if (error) throw error
  return count ?? 0
}
