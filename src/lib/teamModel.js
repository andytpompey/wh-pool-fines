import { supabase } from './supabase'
import { TEAM_ROLE, getTeamRoleLabel, normaliseTeamRole, canManageTeamOperations, canManageTeamRoles, PROTECTED_ACTIONS, canPerformProtectedAction, PROTECTED_ACTION } from './permissions'

function handle(result) {
  if (result.error) throw result.error
  return result.data
}

async function sha256(value) {
  const data = new TextEncoder().encode(value)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(digest)).map(byte => byte.toString(16).padStart(2, '0')).join('')
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
  return canManageTeamOperations({ membership: { role: normaliseTeamRole(role), status: 'active' }, platformRole })
}

export function canCaptainManageRoles(role) {
  return canManageTeamRoles({ membership: { role: normaliseTeamRole(role), status: 'active' } })
}

export async function createTeam({ name, createdBy, joinCode = null }) {
  return handle(await supabase
    .from('teams')
    .insert({ name, created_by: createdBy ?? null, join_code: joinCode })
    .select('*')
    .single())
}

export async function getTeamById(teamId) {
  if (!teamId) return null
  const row = handle(await supabase
    .from('teams')
    .select('*')
    .eq('id', teamId)
    .maybeSingle())
  return row ?? null
}

export async function getTeamByJoinCode(joinCode) {
  if (!joinCode) return null
  const row = handle(await supabase
    .from('teams')
    .select('*')
    .eq('join_code', joinCode.trim().toUpperCase())
    .maybeSingle())
  return row ?? null
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

export async function createTeamInvite({
  teamId,
  email,
  token,
  playerId = null,
  invitedByPlayerId = null,
  expiresAt = null,
}) {
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

export async function upsertPendingTeamInvite({
  teamId,
  email,
  token,
  playerId = null,
  invitedByPlayerId = null,
  expiresAt = null,
}) {
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

export async function setTeamUnlockCode({ teamId, unlockCode }) {
  if (!teamId) throw new Error('Team is required.')
  const normalizedUnlockCode = unlockCode?.trim()
  if (!normalizedUnlockCode) throw new Error('Unlock code is required.')

  const unlockCodeHash = await sha256(normalizedUnlockCode)
  return handle(await supabase
    .from('teams')
    .update({
      unlock_code_hash: unlockCodeHash,
      unlock_code_reset_required: false,
      unlock_code_last_rotated_at: new Date().toISOString(),
    })
    .eq('id', teamId)
    .select('*')
    .single())
}

export async function verifyTeamUnlockCode({ teamId, unlockCode }) {
  if (!teamId || !unlockCode?.trim()) return false
  const team = await getTeamById(teamId)
  if (!team?.unlock_code_hash) return false
  const unlockCodeHash = await sha256(unlockCode.trim())
  return unlockCodeHash === team.unlock_code_hash
}

export async function markTeamUnlockCodeResetRequired(teamId) {
  if (!teamId) throw new Error('Team is required.')
  return handle(await supabase
    .from('teams')
    .update({ unlock_code_hash: null, unlock_code_reset_required: true })
    .eq('id', teamId)
    .select('*')
    .single())
}

export async function canActorPerformProtectedAction({ action, membership, platformRole, teamId, unlockCode }) {
  if (!PROTECTED_ACTIONS.includes(action)) return false
  const unlockCodeVerified = await verifyTeamUnlockCode({ teamId, unlockCode })
  return canPerformProtectedAction({ action, membership, platformRole, unlockCodeVerified })
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
  } : null,
})

export async function listMembershipsForPlayer(playerId) {
  if (!playerId) return []
  const rows = handle(await supabase
    .from('team_memberships')
    .select('id, role, status, joined_at, teams ( id, name, join_code, created_at, unlock_code_reset_required, unlock_code_last_rotated_at )')
    .eq('player_id', playerId)
    .eq('status', 'active')
    .order('joined_at'))

  return (rows ?? []).map(normaliseMembership).filter(membership => membership.team)
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
