import { supabase } from './supabase'

function handle(result) {
  if (result.error) throw result.error
  return result.data
}

export async function createTeam({ name, createdBy, joinCode = null }) {
  return handle(await supabase
    .from('teams')
    .insert({ name, created_by: createdBy ?? null, join_code: joinCode })
    .select('*')
    .single())
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

export async function addTeamMembership({ teamId, playerId, role = 'member', status = 'active' }) {
  return handle(await supabase
    .from('team_memberships')
    .upsert(
      { team_id: teamId, player_id: playerId, role, status },
      { onConflict: 'team_id,player_id' },
    )
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
  return row ?? null
}

export async function listTeamMemberships(teamId) {
  return handle(await supabase
    .from('team_memberships')
    .select('*')
    .eq('team_id', teamId)
    .order('joined_at'))
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
        updated_at: new Date().toISOString(),
      })
      .eq('id', existing.id)
      .select('*')
      .single())
  }

  return createTeamInvite({ teamId, email: normalizedEmail, token, playerId, invitedByPlayerId, expiresAt })
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


const normaliseMembership = row => ({
  id: row.id,
  role: row.role,
  status: row.status,
  joinedAt: row.joined_at,
  team: row.teams ? {
    id: row.teams.id,
    name: row.teams.name,
    joinCode: row.teams.join_code,
    createdAt: row.teams.created_at,
  } : null,
})

export async function listMembershipsForPlayer(playerId) {
  if (!playerId) return []
  const rows = handle(await supabase
    .from('team_memberships')
    .select('id, role, status, joined_at, teams ( id, name, join_code, created_at )')
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
