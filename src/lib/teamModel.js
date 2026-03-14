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

export async function listTeamMemberships(teamId) {
  return handle(await supabase
    .from('team_memberships')
    .select('*')
    .eq('team_id', teamId)
    .order('joined_at'))
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
