/**
 * db.js — all Supabase database operations for White Horse Pool Fines
 */

import { supabase } from './supabase'

function handle(result) {
  if (result.error) throw result.error
  return result.data
}

export async function loadAll() {
  const [players, fineTypes, seasons, matchRows, fineRows, subRows, mpRows] =
    await Promise.all([
      supabase.from('players').select('*').order('name'),
      supabase.from('fine_types').select('*').order('cost').order('name'),
      supabase.from('seasons').select('*').order('name'),
      supabase.from('matches').select('*').order('date', { ascending: false }),
      supabase.from('fines').select('*'),
      supabase.from('subs').select('*'),
      supabase.from('match_players').select('*'),
    ])

  ;[players, fineTypes, seasons, matchRows, fineRows, subRows, mpRows].forEach(r => {
    if (r.error) throw r.error
  })

  const matches = matchRows.data.map(m => ({
    ...m,
    seasonId: m.season_id,
    fines: fineRows.data.filter(f => f.match_id === m.id).map(normalFine),
    subs: subRows.data.filter(s => s.match_id === m.id).map(normalSub),
    playerIds: mpRows.data.filter(p => p.match_id === m.id).map(p => p.player_id),
  }))

  return {
    players: players.data.map(normalPlayer),
    fineTypes: fineTypes.data.map(normalFineType),
    seasons: seasons.data.map(normalSeason),
    matches,
  }
}

// ─── normalise DB rows to app shape ──────────────────────────────────────────
const normalPlayer   = r => ({
  id: r.id,
  name: r.name,
  email: r.email ?? '',
  mobile: r.mobile ?? '',
  preferredAuthMethod: r.preferred_auth_method ?? 'email',
  authUserId: r.auth_user_id ?? null,
})
const normalFineType = r => ({ id: r.id, name: r.name, cost: Number(r.cost) })
const normalSeason = r => ({ id: r.id, name: r.name, type: r.type })
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
    email: player.email || null,
    mobile: player.mobile || null,
    preferred_auth_method: player.preferredAuthMethod || null,
  }
  if (player.id) payload.id = player.id

  return normalPlayer(handle(await supabase.from('players').insert(payload).select().single()))
}

export async function updatePlayer(player) {
  return normalPlayer(handle(await supabase.from('players').update({
    name: player.name,
    email: player.email || null,
    mobile: player.mobile || null,
    preferred_auth_method: player.preferredAuthMethod || null,
    auth_user_id: player.authUserId || null,
  }).eq('id', player.id).select().single()))
}

export async function deletePlayer(id) {
  handle(await supabase.from('players').delete().eq('id', id))
}

export async function addFineType(ft) {
  return normalFineType(handle(await supabase.from('fine_types').insert({ id: ft.id, name: ft.name, cost: ft.cost }).select().single()))
}

export async function updateFineType(ft) {
  return normalFineType(handle(await supabase.from('fine_types').update({ name: ft.name, cost: ft.cost }).eq('id', ft.id).select().single()))
}

export async function deleteFineType(id) {
  handle(await supabase.from('fine_types').delete().eq('id', id))
}

export async function addSeason(season) {
  return normalSeason(handle(await supabase.from('seasons').insert({ id: season.id, name: season.name, type: season.type }).select().single()))
}

export async function updateSeason(season) {
  return normalSeason(handle(await supabase.from('seasons').update({ name: season.name, type: season.type }).eq('id', season.id).select().single()))
}

export async function deleteSeason(id) {
  handle(await supabase.from('seasons').delete().eq('id', id))
}

export async function addMatch(match) {
  const row = handle(await supabase.from('matches').insert({
    id: match.id,
    date: match.date,
    season_id: match.seasonId,
    opponent: match.opponent,
    submitted: match.submitted,
  }).select().single())
  return { ...match, ...row, seasonId: row.season_id }
}

export async function updateMatch(match) {
  handle(await supabase.from('matches').update({
    date: match.date,
    season_id: match.seasonId,
    opponent: match.opponent,
    submitted: match.submitted,
  }).eq('id', match.id))

  handle(await supabase.from('match_players').delete().eq('match_id', match.id))
  if (match.playerIds?.length) {
    handle(await supabase.from('match_players').insert(match.playerIds.map(pid => ({ match_id: match.id, player_id: pid }))))
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
  if (players.length)   handle(await supabase.from('players').insert(players.map(p => ({
    id: p.id,
    name: p.name,
    email: p.email || null,
    mobile: p.mobile || null,
    preferred_auth_method: p.preferredAuthMethod || null,
    auth_user_id: p.authUserId || null,
  }))))
  if (fineTypes.length) handle(await supabase.from('fine_types').insert(fineTypes.map(f => ({ id: f.id, name: f.name, cost: f.cost }))))
  if (seasons.length) handle(await supabase.from('seasons').insert(seasons.map(s => ({ id: s.id, name: s.name, type: s.type }))))

  for (const m of matches) {
    handle(await supabase.from('matches').insert({ id: m.id, date: m.date, season_id: m.seasonId, opponent: m.opponent, submitted: m.submitted }))
    if (m.playerIds?.length) handle(await supabase.from('match_players').insert(m.playerIds.map(pid => ({ match_id: m.id, player_id: pid }))))
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
  return normalPlayer(handle(await supabase.from('players').update({ auth_user_id: authUserId }).eq('id', playerId).select().single()))
}
