/**
 * db.js — all Supabase database operations for White Horse Pool Fines
 */

import { supabase } from './supabase'
import { AUDIT_ACTION, logAuditEventSafely } from './audit'

function handle(result) {
  if (result.error) throw result.error
  return result.data
}

export async function loadAll({ teamId } = {}) {
  if (!teamId) {
    return { players: [], fineTypes: [], seasons: [], matches: [] }
  }
  const [playerMembershipRows, players, fineTypes, seasons, matchRows, fineRows, subRows, mpRows] =
    await Promise.all([
      supabase.from('team_memberships').select('player_id').eq('team_id', teamId).eq('status', 'active'),
      supabase.from('players').select('*').order('display_name', { ascending: true, nullsFirst: false }).order('name'),
      supabase.from('fine_types').select('*').eq('team_id', teamId).order('cost').order('name'),
      supabase.from('seasons').select('*').eq('team_id', teamId).order('name'),
      supabase.from('matches').select('*').eq('team_id', teamId).order('date', { ascending: false }),
      supabase.from('fines').select('*'),
      supabase.from('subs').select('*'),
      supabase.from('match_players').select('*'),
    ])

  ;[playerMembershipRows, players, fineTypes, seasons, matchRows, fineRows, subRows, mpRows].forEach(r => {
    if (r.error) throw r.error
  })

  const teamPlayerIds = new Set((playerMembershipRows.data ?? []).map(row => row.player_id))

  const matches = matchRows.data.map(m => ({
    ...m,
    seasonId: m.season_id,
    teamId: m.team_id,
    sourceCompetitionId: m.source_competition_id ?? null,
    sourceCompetitionName: m.source_competition_name ?? null,
    sourceTeamRole: m.source_team_role ?? null,
    sourceVenueId: m.source_venue_id ?? null,
    sourceTeamVenueId: m.source_team_venue_id ?? null,
    sourceTeamVenueName: m.source_team_venue_name ?? null,
    fines: fineRows.data.filter(f => f.match_id === m.id).map(normalFine),
    subs: subRows.data.filter(s => s.match_id === m.id).map(normalSub),
    playerIds: mpRows.data.filter(p => p.match_id === m.id).map(p => p.player_id),
    driverIds: mpRows.data.filter(p => p.match_id === m.id && p.is_driver).map(p => p.player_id),
    venue: m.venue ?? 'home',
  }))

  return {
    players: players.data.map(normalPlayer).filter(player => teamPlayerIds.has(player.id)),
    fineTypes: fineTypes.data.map(normalFineType),
    seasons: seasons.data.map(normalSeason),
    matches,
  }
}

// ─── normalise DB rows to app shape ──────────────────────────────────────────
const normalPlayer   = r => ({
  id: r.id,
  name: r.display_name ?? r.name,
  email: r.email ?? '',
  mobile: r.mobile ?? '',
  preferredAuthMethod: r.preferred_auth_method ?? 'email',
  receiveTeamNotifications: Boolean(r.receive_team_notifications ?? true),
  authUserId: r.user_id ?? r.auth_user_id ?? null,
})
const normalFineType = r => ({ id: r.id, name: r.name, cost: Number(r.cost), teamId: r.team_id ?? null })
const normalSeason = r => ({
  id: r.id,
  name: r.name,
  type: r.type,
  teamId: r.team_id ?? null,
  source: r.source ?? null,
  sourceLeagueSlug: r.source_league_slug ?? null,
  sourceSeasonTeamId: r.source_season_team_id ?? null,
  sourceUrl: r.source_url ?? null,
  sourceLastRefreshedAt: r.source_last_refreshed_at ?? null,
  sourceLastRefreshStatus: r.source_last_refresh_status ?? null,
})
const normalFine = r => ({
  id: r.id, matchId: r.match_id, playerId: r.player_id,
  fineTypeId: r.fine_type_id, playerName: r.player_name,
  fineName: r.fine_name, cost: Number(r.cost), paid: r.paid,
})
const normalSub = r => ({
  id: r.id, matchId: r.match_id, playerId: r.player_id,
  playerName: r.player_name, amount: Number(r.amount), paid: r.paid,
})

export async function addPlayer(player) {
  const payload = {
    name: player.name,
    display_name: player.name,
    email: player.email || `player-${crypto.randomUUID()}@placeholder.local`,
    mobile: player.mobile || null,
    preferred_auth_method: player.preferredAuthMethod || null,
  }
  if (!(player.email || '').trim()) throw new Error('Player email is required')
  if (player.id) payload.id = player.id

  return normalPlayer(handle(await supabase.from('players').insert(payload).select().single()))
}

export async function updatePlayer(player) {
  if (!(player.email || '').trim()) throw new Error('Player email is required')
  return normalPlayer(handle(await supabase.from('players').update({
    name: player.name,
    display_name: player.name,
    email: player.email || `player-${crypto.randomUUID()}@placeholder.local`,
    mobile: player.mobile || null,
    preferred_auth_method: player.preferredAuthMethod || null,
    auth_user_id: player.authUserId || null,
    user_id: player.authUserId || null,
  }).eq('id', player.id).select().single()))
}

export async function deletePlayer(id) {
  handle(await supabase.from('players').delete().eq('id', id))
}

export async function addFineType(ft) {
  return normalFineType(handle(await supabase.from('fine_types').insert({ id: ft.id, name: ft.name, cost: ft.cost, team_id: ft.teamId ?? null }).select().single()))
}

export async function updateFineType(ft) {
  return normalFineType(handle(await supabase.from('fine_types').update({ name: ft.name, cost: ft.cost, team_id: ft.teamId ?? null }).eq('id', ft.id).select().single()))
}

export async function deleteFineType(id) {
  handle(await supabase.from('fine_types').delete().eq('id', id))
}

export async function deleteFineTypeWithAudit({ id, teamId, actorMembership, platformRole = null, fineTypeName = null }) {
  await deleteFineType(id)
  await logAuditEventSafely({
    action: AUDIT_ACTION.PROTECTED_RECORD_DELETED,
    teamId,
    actorMembership,
    platformRole,
    outcome: 'success',
    targetEntityType: 'fine_type',
    targetEntityId: id,
    payload: { label: fineTypeName, protectedAction: 'delete_fine_type' },
  })
}

export async function addSeason(season) {
  return normalSeason(handle(await supabase.from('seasons').insert({
    id: season.id,
    name: season.name,
    type: season.type,
    team_id: season.teamId ?? null,
    source: season.source ?? null,
    source_league_slug: season.sourceLeagueSlug ?? null,
    source_season_team_id: season.sourceSeasonTeamId ?? null,
    source_url: season.sourceUrl ?? null,
    source_last_refreshed_at: season.sourceLastRefreshedAt ?? null,
    source_last_refresh_status: season.sourceLastRefreshStatus ?? null,
  }).select().single()))
}

export async function updateSeason(season) {
  return normalSeason(handle(await supabase.from('seasons').update({
    name: season.name,
    type: season.type,
    team_id: season.teamId ?? null,
    source_last_refreshed_at: season.sourceLastRefreshedAt ?? null,
    source_last_refresh_status: season.sourceLastRefreshStatus ?? null,
  }).eq('id', season.id).select().single()))
}

export async function importRackemSeason({ teamId, season, teamPage, idFactory }) {
  if (!teamId || !season?.seasonTeamId || !teamPage) throw new Error('RackEm season data is incomplete.')
  const now = new Date().toISOString()
  const existingSeason = handle(await supabase
    .from('seasons')
    .select('*')
    .eq('team_id', teamId)
    .eq('source', 'rackem')
    .eq('source_season_team_id', season.seasonTeamId)
    .maybeSingle())

  const seasonPayload = {
    name: season.name,
    type: 'League',
    team_id: teamId,
    source: 'rackem',
    source_league_slug: teamPage.leagueSlug,
    source_season_team_id: season.seasonTeamId,
    source_url: season.url,
    source_last_refreshed_at: now,
    source_last_refresh_status: 'success',
  }
  const seasonRow = existingSeason
    ? handle(await supabase.from('seasons').update(seasonPayload).eq('id', existingSeason.id).select().single())
    : handle(await supabase.from('seasons').insert({ id: idFactory(), ...seasonPayload }).select().single())

  const existingMatches = handle(await supabase
    .from('matches')
    .select('id, source_identity, date, source_matchday, source_home_team_id, source_away_team_id')
    .eq('team_id', teamId)
    .eq('season_id', seasonRow.id)
    .eq('source', 'rackem'))
  const existingByIdentity = new Map((existingMatches ?? []).map(match => [match.source_identity, match.id]))
  const existingByFixture = new Map((existingMatches ?? []).map(match => [[
    match.date,
    match.source_matchday,
    match.source_home_team_id,
    match.source_away_team_id,
  ].join(':'), match.id]))

  let created = 0
  let updated = 0
  for (const match of teamPage.matches) {
    const isHome = match.homeTeam.id === season.seasonTeamId
    const hasVenueComparison = Boolean(match.venue?.id && teamPage.venue?.id)
    const isAtTeamVenue = hasVenueComparison
      ? match.venue.id === teamPage.venue.id
      : isHome
    const opponent = isHome ? match.awayTeam : match.homeTeam
    const fixtureIdentity = [match.date, match.matchday, match.homeTeam.id, match.awayTeam.id].join(':')
    const existingId = existingByIdentity.get(match.sourceIdentity) ?? existingByFixture.get(fixtureIdentity)
    const payload = {
      date: match.date,
      season_id: seasonRow.id,
      opponent: opponent.name,
      submitted: false,
      venue: isAtTeamVenue ? 'home' : 'away',
      team_id: teamId,
      source: 'rackem',
      source_identity: match.sourceIdentity,
      source_scorecard_id: match.scorecardId,
      source_matchday: match.matchday,
      source_competition_id: match.competitionId ?? null,
      source_competition_name: match.competitionName ?? 'League Match',
      source_status: match.status,
      source_home_score: match.homeScore ?? null,
      source_away_score: match.awayScore ?? null,
      source_home_team_id: match.homeTeam.id,
      source_away_team_id: match.awayTeam.id,
      source_team_role: isHome ? 'home' : 'away',
      source_venue_id: match.venue?.id ?? null,
      source_venue_name: match.venue?.name ?? null,
      source_team_venue_id: teamPage.venue?.id ?? null,
      source_team_venue_name: teamPage.venue?.name ?? null,
      source_last_seen_at: now,
    }
    if (existingId) {
      handle(await supabase.from('matches').update(payload).eq('id', existingId))
      updated += 1
    } else {
      handle(await supabase.from('matches').insert({ id: idFactory(), ...payload }))
      created += 1
    }
  }

  return {
    season: normalSeason(seasonRow),
    created,
    updated,
    total: teamPage.matches.length,
  }
}

export async function deleteSeason(id) {
  handle(await supabase.from('seasons').delete().eq('id', id))
}

export async function getSeasonOutstandingFines(seasonId) {
  const matchRows = handle(await supabase
    .from('matches')
    .select('id')
    .eq('season_id', seasonId))
  const matchIds = (matchRows ?? []).map(match => match.id)
  if (!matchIds.length) return { count: 0, total: 0 }

  const fineRows = handle(await supabase
    .from('fines')
    .select('id, cost')
    .in('match_id', matchIds)
    .eq('paid', false))

  return {
    count: fineRows?.length ?? 0,
    total: (fineRows ?? []).reduce((sum, fine) => sum + Number(fine.cost ?? 0), 0),
  }
}

export async function deleteSeasonWithAudit({ id, teamId, actorMembership, platformRole = null, seasonName = null }) {
  await deleteSeason(id)
  await logAuditEventSafely({
    action: AUDIT_ACTION.PROTECTED_RECORD_DELETED,
    teamId,
    actorMembership,
    platformRole,
    outcome: 'success',
    targetEntityType: 'season',
    targetEntityId: id,
    payload: { label: seasonName, protectedAction: 'delete_season' },
  })
}

export async function addMatch(match) {
  const row = handle(await supabase.from('matches').insert({
    id: match.id,
    date: match.date,
    season_id: match.seasonId,
    opponent: match.opponent,
    submitted: match.submitted,
    venue: match.venue ?? 'home',
    team_id: match.teamId ?? null,
  }).select().single())
  return { ...match, ...row, seasonId: row.season_id }
}

export async function updateMatch(match) {
  handle(await supabase.from('matches').update({
    date: match.date,
    season_id: match.seasonId,
    opponent: match.opponent,
    submitted: match.submitted,
    venue: match.venue ?? 'home',
    team_id: match.teamId ?? null,
  }).eq('id', match.id))

  handle(await supabase.from('match_players').delete().eq('match_id', match.id))
  if (match.playerIds?.length) {
    handle(await supabase.from('match_players').insert(match.playerIds.map(pid => ({
      match_id: match.id,
      player_id: pid,
      is_driver: (match.driverIds ?? []).includes(pid),
    }))))
  }

  handle(await supabase.from('fines').delete().eq('match_id', match.id))
  if (match.fines?.length) {
    handle(await supabase.from('fines').insert(match.fines.map(f => ({
      id: f.id,
      match_id: match.id,
      player_id: f.playerId,
      fine_type_id: f.fineTypeId,
      player_name: f.playerName,
      fine_name: f.fineName,
      cost: f.cost,
      paid: f.paid,
    }))))
  }

  handle(await supabase.from('subs').delete().eq('match_id', match.id))
  if (match.subs?.length) {
    handle(await supabase.from('subs').insert(match.subs.map(s => ({
      id: s.id,
      match_id: match.id,
      player_id: s.playerId,
      player_name: s.playerName,
      amount: s.amount,
      paid: s.paid,
    }))))
  }
}

export async function deleteMatch(id) {
  handle(await supabase.from('matches').delete().eq('id', id))
}

export async function deleteMatchWithAudit({ id, teamId, actorMembership, platformRole = null, matchDate = null }) {
  await deleteMatch(id)
  await logAuditEventSafely({
    action: AUDIT_ACTION.PROTECTED_RECORD_DELETED,
    teamId,
    actorMembership,
    platformRole,
    outcome: 'success',
    targetEntityType: 'match',
    targetEntityId: id,
    payload: { matchDate, protectedAction: 'delete_match' },
  })
}

export async function logProtectedRecordDeletion({ teamId, actorMembership, platformRole = null, entityType, entityId, payload = null }) {
  await logAuditEventSafely({
    action: AUDIT_ACTION.PROTECTED_RECORD_DELETED,
    teamId,
    actorMembership,
    platformRole,
    outcome: 'success',
    targetEntityType: entityType,
    targetEntityId: entityId,
    payload,
  })
}

export async function logProtectedRecordReversal({ teamId, actorMembership, platformRole = null, entityType, entityId, payload = null }) {
  await logAuditEventSafely({
    action: AUDIT_ACTION.PROTECTED_RECORD_REVERSED,
    teamId,
    actorMembership,
    platformRole,
    outcome: 'success',
    targetEntityType: entityType,
    targetEntityId: entityId,
    payload,
  })
}

export async function importAll({ players, fineTypes, seasons, matches }) {
  await Promise.all([
    supabase.from('fines').delete().neq('id', '00000000-0000-0000-0000-000000000000'),
    supabase.from('subs').delete().neq('id', '00000000-0000-0000-0000-000000000000'),
    supabase.from('match_players').delete().neq('match_id', '00000000-0000-0000-0000-000000000000'),
    supabase.from('matches').delete().neq('id', '00000000-0000-0000-0000-000000000000'),
    supabase.from('fine_types').delete().neq('id', '00000000-0000-0000-0000-000000000000'),
    supabase.from('seasons').delete().neq('id', '00000000-0000-0000-0000-000000000000'),
    supabase.from('players').delete().neq('id', '00000000-0000-0000-0000-000000000000'),
  ])

  // Insert in dependency order
  if (players.some(p => !(p.email || '').trim())) throw new Error('All players must include an email address before import')
  if (players.length)   handle(await supabase.from('players').insert(players.map(p => ({
    id: p.id,
    name: p.name,
    display_name: p.name,
    email: p.email || `player-${p.id}@placeholder.local`,
    mobile: p.mobile || null,
    preferred_auth_method: p.preferredAuthMethod || null,
    user_id: p.authUserId || null,
  }))))
  if (fineTypes.length) handle(await supabase.from('fine_types').insert(fineTypes.map(f => ({ id: f.id, name: f.name, cost: f.cost, team_id: f.teamId ?? null }))))
  if (seasons.length) handle(await supabase.from('seasons').insert(seasons.map(s => ({ id: s.id, name: s.name, type: s.type, team_id: s.teamId ?? null }))))

  for (const m of matches) {
    handle(await supabase.from('matches').insert({ id: m.id, date: m.date, season_id: m.seasonId, opponent: m.opponent, venue: m.venue ?? 'home', submitted: m.submitted, team_id: m.teamId ?? null }))
    if (m.playerIds?.length) handle(await supabase.from('match_players').insert(m.playerIds.map(pid => ({ match_id: m.id, player_id: pid, is_driver: (m.driverIds ?? []).includes(pid) }))))
    if (m.fines?.length) handle(await supabase.from('fines').insert(m.fines.map(f => ({ id: f.id, match_id: m.id, player_id: f.playerId, fine_type_id: f.fineTypeId, player_name: f.playerName, fine_name: f.fineName, cost: f.cost, paid: f.paid }))))
    if (m.subs?.length) handle(await supabase.from('subs').insert(m.subs.map(s => ({ id: s.id, match_id: m.id, player_id: s.playerId, player_name: s.playerName, amount: s.amount, paid: s.paid }))))
  }
}


export async function findPlayerByAuth({ method, value }) {
  const normalized = value?.trim()
  if (!normalized) return null

  const column = method === 'whatsapp' ? 'mobile' : 'email'
  const queryValue = method === 'email' ? normalized.toLowerCase() : normalized

  const query = supabase.from('players').select('*').limit(1)
  const row = method === 'email'
    ? handle(await query.ilike(column, queryValue).maybeSingle())
    : handle(await query.eq(column, queryValue).maybeSingle())
  return row ? normalPlayer(row) : null
}

export async function attachAuthUser(playerId, authUserId) {
  if (!playerId || !authUserId) return null
  return normalPlayer(handle(await supabase.from('players').update({ user_id: authUserId, auth_user_id: authUserId }).eq('id', playerId).select().single()))
}

export async function linkPlayerToAuthUser({ playerId, authUserId }) {
  if (!playerId || !authUserId) throw new Error('playerId and authUserId are required')
  return normalPlayer(handle(await supabase
    .from('players')
    .update({ user_id: authUserId, auth_user_id: authUserId })
    .eq('id', playerId)
    .select()
    .single()))
}

export async function findPlayerByEmail(email) {
  const normalizedEmail = email?.trim().toLowerCase()
  if (!normalizedEmail) return null
  const row = handle(await supabase.from('players').select('*').ilike('email', normalizedEmail).limit(1).maybeSingle())
  return row ? normalPlayer(row) : null
}

export async function createOrReusePlayerByEmail({ email, displayName }) {
  const normalizedEmail = email?.trim().toLowerCase()
  const trimmedDisplayName = displayName?.trim()
  if (!normalizedEmail) throw new Error('Email is required')
  if (!trimmedDisplayName) throw new Error('Display name is required')

  const existing = await findPlayerByEmail(normalizedEmail)
  if (existing) {
    const nextName = existing.name?.trim() || trimmedDisplayName
    if (nextName !== existing.name) {
      return updatePlayer({ ...existing, name: nextName })
    }
    return existing
  }

  return addPlayer({
    name: trimmedDisplayName,
    email: normalizedEmail,
    mobile: '',
    preferredAuthMethod: 'email',
  })
}

export async function createOrReusePendingTeamInvite({ teamId, email, invitedByPlayerId = null, expiresAt = null, token }) {
  const normalizedEmail = email?.trim().toLowerCase()
  if (!teamId) throw new Error('teamId is required')
  if (!normalizedEmail) throw new Error('Email is required')

  const existing = handle(await supabase
    .from('team_invites')
    .select('*')
    .eq('team_id', teamId)
    .ilike('email', normalizedEmail)
    .eq('status', 'pending')
    .limit(1)
    .maybeSingle())

  if (existing) return existing

  return handle(await supabase
    .from('team_invites')
    .insert({
      team_id: teamId,
      email: normalizedEmail,
      invited_by_player_id: invitedByPlayerId,
      expires_at: expiresAt,
      token,
      status: 'pending',
    })
    .select('*')
    .single())
}


// TODO: player records are still global profiles rather than per-team roster rows.
// For now we load all players so legacy screens keep working while matches/fines/seasons/fine types are team-scoped.
