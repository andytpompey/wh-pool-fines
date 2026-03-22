import { supabase } from './supabase'
import { TEAM_ROLE, getTeamRoleLabel, normaliseTeamRole, PROTECTED_ACTIONS, PROTECTED_ACTION, PLATFORM_ROLE } from './permissions'
import { APP_ACTION, assertActionAccess, canAccessAction, getProtectedActionForAppAction } from './accessControl'
import * as auth from './auth'

function handle(result) {
  if (result.error) throw result.error
  return result.data
}

const UNLOCK_CODE_HASH_ITERATIONS = 210000
const UNLOCK_CODE_KEY = 'PBKDF2'
const UNLOCK_CODE_HASH = 'SHA-256'
const UNLOCK_CODE_VERSION = 1
const MAX_VERIFY_ATTEMPTS = 5
const MAX_RESET_ATTEMPTS = 3
const VERIFY_WINDOW_MS = 5 * 60 * 1000
const RESET_WINDOW_MS = 15 * 60 * 1000

function getRandomBytes(size) {
  const bytes = new Uint8Array(size)
  crypto.getRandomValues(bytes)
  return bytes
}

function bufferToHex(buffer) {
  return Array.from(new Uint8Array(buffer), byte => byte.toString(16).padStart(2, '0')).join('')
}

function timingSafeEqualHex(left, right) {
  if (!left || !right) return false
  const leftBytes = left.match(/.{1,2}/g)?.map(part => Number.parseInt(part, 16)) ?? []
  const rightBytes = right.match(/.{1,2}/g)?.map(part => Number.parseInt(part, 16)) ?? []
  const length = Math.max(leftBytes.length, rightBytes.length)
  let mismatch = leftBytes.length === rightBytes.length ? 0 : 1
  for (let index = 0; index < length; index += 1) {
    mismatch |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0)
  }
  return mismatch === 0
}

async function deriveUnlockCodeHash({ unlockCode, saltHex, iterations = UNLOCK_CODE_HASH_ITERATIONS }) {
  const normalizedUnlockCode = unlockCode?.trim()
  if (!normalizedUnlockCode) throw new Error('Unlock code is required.')
  const secret = await crypto.subtle.importKey('raw', new TextEncoder().encode(normalizedUnlockCode), UNLOCK_CODE_KEY, false, ['deriveBits'])
  const salt = Uint8Array.from((saltHex.match(/.{1,2}/g) ?? []).map(part => Number.parseInt(part, 16)))
  const bits = await crypto.subtle.deriveBits({ name: UNLOCK_CODE_KEY, hash: UNLOCK_CODE_HASH, salt, iterations }, secret, 256)
  return bufferToHex(bits)
}

async function hashNewUnlockCode(unlockCode) {
  const saltHex = bufferToHex(getRandomBytes(16))
  const hashHex = await deriveUnlockCodeHash({ unlockCode, saltHex })
  return {
    unlock_code_hash: hashHex,
    unlock_code_salt: saltHex,
    unlock_code_hash_algorithm: 'pbkdf2-sha256',
    unlock_code_hash_iterations: UNLOCK_CODE_HASH_ITERATIONS,
    unlock_code_version: UNLOCK_CODE_VERSION,
  }
}

function getRateLimitState(key) {
  try {
    return JSON.parse(localStorage.getItem(key) || 'null') || { count: 0, start: Date.now() }
  } catch {
    return { count: 0, start: Date.now() }
  }
}

function checkRateLimit({ scope, teamId, limit, windowMs }) {
  const key = `roo-bin:${scope}:${teamId}`
  const now = Date.now()
  const state = getRateLimitState(key)
  if (now - state.start > windowMs) {
    localStorage.setItem(key, JSON.stringify({ count: 1, start: now }))
    return
  }
  if (state.count >= limit) throw new Error('Too many attempts. Please wait and try again.')
  localStorage.setItem(key, JSON.stringify({ count: state.count + 1, start: state.start }))
}

function clearRateLimit({ scope, teamId }) {
  localStorage.removeItem(`roo-bin:${scope}:${teamId}`)
}

async function notifyCaptainsOfUnlockCode({ captainContacts, teamName, unlockCode, reason }) {
  const endpoint = import.meta.env.VITE_TEAM_UNLOCK_CODE_EMAIL_URL
  const recipients = captainContacts.filter(contact => contact?.email && contact.receiveTeamNotifications !== false)
  if (!recipients.length) {
    return { delivered: false, message: 'Unlock code rotated, but no captain notification recipients were available.' }
  }
  if (!endpoint) {
    return { delivered: false, message: 'Unlock code rotated. Captain notification delivery is not configured yet.' }
  }

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      teamName,
      unlockCode,
      reason,
      recipients: recipients.map(recipient => ({
        email: recipient.email,
        playerName: recipient.playerName,
      })),
    }),
  })
  const body = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(body?.error || 'Failed to deliver unlock code notifications.')
  return { delivered: true, message: body?.message || 'Unlock code notifications sent.' }
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

async function updateTeamUnlockCodeRecord({ teamId, unlockCode, resetRequired = false }) {
  if (!teamId) throw new Error('Team is required.')
  const hashedPayload = await hashNewUnlockCode(unlockCode)
  clearRateLimit({ scope: 'unlock-verify', teamId })
  clearRateLimit({ scope: 'unlock-reset', teamId })
  return handle(await supabase
    .from('teams')
    .update({
      ...hashedPayload,
      unlock_code_reset_required: resetRequired,
      unlock_code_last_rotated_at: new Date().toISOString(),
      unlock_code_reset_requested_at: new Date().toISOString(),
    })
    .eq('id', teamId)
    .select('*')
    .single())
}

export async function setTeamUnlockCode({ teamId, unlockCode, actorMembership }) {
  assertActionAccess({ action: APP_ACTION.MANAGE_UNLOCK_CODE, membership: actorMembership, message: 'Only captains can set a team unlock code.' })
  const existingTeam = await getTeamById(teamId)
  if (existingTeam?.unlock_code_hash) throw new Error('Unlock code already exists. Use change unlock code instead.')
  return updateTeamUnlockCodeRecord({ teamId, unlockCode, resetRequired: false })
}

export async function changeTeamUnlockCode({ teamId, currentUnlockCode, nextUnlockCode, actorMembership }) {
  assertActionAccess({ action: APP_ACTION.MANAGE_UNLOCK_CODE, membership: actorMembership, message: 'Only captains can change a team unlock code.' })
  const currentValid = await verifyTeamUnlockCode({ teamId, unlockCode: currentUnlockCode })
  if (!currentValid) throw new Error('Current unlock code is incorrect.')
  return updateTeamUnlockCodeRecord({ teamId, unlockCode: nextUnlockCode, resetRequired: false })
}

function generateTeamUnlockCode() {
  return Array.from(getRandomBytes(6), byte => (byte % 10).toString()).join('')
}

export async function verifyTeamUnlockCode({ teamId, unlockCode }) {
  if (!teamId || !unlockCode?.trim()) return false
  checkRateLimit({ scope: 'unlock-verify', teamId, limit: MAX_VERIFY_ATTEMPTS, windowMs: VERIFY_WINDOW_MS })
  const team = await getTeamById(teamId)
  if (!team?.unlock_code_hash || !team?.unlock_code_salt) return false
  const unlockCodeHash = await deriveUnlockCodeHash({
    unlockCode: unlockCode.trim(),
    saltHex: team.unlock_code_salt,
    iterations: team.unlock_code_hash_iterations || UNLOCK_CODE_HASH_ITERATIONS,
  })
  const matched = timingSafeEqualHex(unlockCodeHash, team.unlock_code_hash)
  if (matched) clearRateLimit({ scope: 'unlock-verify', teamId })
  return matched
}

export async function requestCaptainUnlockCodeReset({ teamId, actorMembership, verificationMethod, verificationTarget, otpToken, captainContacts = [], teamName }) {
  assertActionAccess({ action: APP_ACTION.MANAGE_UNLOCK_CODE, membership: actorMembership, message: 'Only captains can request an unlock code reset.' })
  checkRateLimit({ scope: 'unlock-reset', teamId, limit: MAX_RESET_ATTEMPTS, windowMs: RESET_WINDOW_MS })
  if (verificationMethod === 'whatsapp') await auth.verifyWhatsAppOtp(verificationTarget, otpToken)
  else await auth.verifyEmailOtp(verificationTarget, otpToken)

  const newUnlockCode = generateTeamUnlockCode()
  await updateTeamUnlockCodeRecord({ teamId, unlockCode: newUnlockCode, resetRequired: false })
  const notification = await notifyCaptainsOfUnlockCode({ captainContacts, teamName, unlockCode: newUnlockCode, reason: 'captain_recovery' })
  return { success: true, notification }
}

export async function triggerAdminUnlockCodeReset({ teamId, platformRole, captainContacts = [], teamName }) {
  assertActionAccess({ action: APP_ACTION.ADMIN_RESET_UNLOCK_CODE, platformRole, message: 'Only platform admins can trigger team unlock code resets.' })
  const newUnlockCode = generateTeamUnlockCode()
  await updateTeamUnlockCodeRecord({ teamId, unlockCode: newUnlockCode, resetRequired: false })
  const notification = await notifyCaptainsOfUnlockCode({ captainContacts, teamName, unlockCode: newUnlockCode, reason: 'platform_admin_reset' })
  return { success: true, notification }
}

export async function markTeamUnlockCodeResetRequired(teamId) {
  if (!teamId) throw new Error('Team is required.')
  return handle(await supabase
    .from('teams')
    .update({ unlock_code_hash: null, unlock_code_salt: null, unlock_code_reset_required: true })
    .eq('id', teamId)
    .select('*')
    .single())
}


function getAppActionForProtectedAction(action) {
  return Object.values(APP_ACTION).find(candidate => getProtectedActionForAppAction(candidate) === action) ?? null
}

export async function canActorPerformProtectedAction({ action, membership, platformRole, teamId, unlockCode }) {
  if (!PROTECTED_ACTIONS.includes(action)) return false
  const unlockCodeVerified = await verifyTeamUnlockCode({ teamId, unlockCode })
  return canAccessAction({ action: getAppActionForProtectedAction(action), membership, platformRole, unlockCodeVerified })
}

export async function assertProtectedActionAccess({ action, membership, platformRole, teamId, unlockCode, message = 'Forbidden' }) {
  const protectedAction = getProtectedActionForAppAction(action) ?? action
  if (!PROTECTED_ACTIONS.includes(protectedAction)) throw new Error('Unsupported protected action.')
  const unlockCodeVerified = await verifyTeamUnlockCode({ teamId, unlockCode })
  const appAction = getProtectedActionForAppAction(action) ? action : getAppActionForProtectedAction(protectedAction)
  assertActionAccess({ action: appAction, membership, platformRole, unlockCodeVerified, message })
  return true
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
