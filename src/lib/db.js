/**
 * db.js — all Supabase database operations for White Horse Pool Fines
 *
 * Data model:
 *   players       (id uuid, name text, created_at timestamptz)
 *   fine_types    (id uuid, name text, cost numeric, created_at timestamptz)
 *   seasons       (id uuid, name text, type text, created_at timestamptz)
 *   matches       (id uuid, date date, season_id uuid, opponent text, submitted bool, created_at timestamptz)
 *   match_players (match_id uuid, player_id uuid)  -- who played in each match
 *   fines         (id uuid, match_id uuid, player_id uuid, fine_type_id uuid,
 *                  player_name text, fine_name text, cost numeric, paid bool, created_at timestamptz)
 *   subs          (id uuid, match_id uuid, player_id uuid,
 *                  player_name text, amount numeric, paid bool, created_at timestamptz)
 */

import { supabase } from './supabase'

// ─── helpers ──────────────────────────────────────────────────────────────────
function handle(result) {
  if (result.error) throw result.error
  return result.data
}

// ─── LOAD ALL (called once on mount) ─────────────────────────────────────────
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

  // Assemble matches with nested fines, subs, playerIds
  const matches = matchRows.data.map(m => ({
    ...m,
    seasonId:  m.season_id,
    fines:     fineRows.data.filter(f => f.match_id === m.id).map(normalFine),
    subs:      subRows.data.filter(s => s.match_id === m.id).map(normalSub),
    playerIds: mpRows.data.filter(p => p.match_id === m.id).map(p => p.player_id),
  }))

  return {
    players:   players.data.map(normalPlayer),
    fineTypes: fineTypes.data.map(normalFineType),
    seasons:   seasons.data.map(normalSeason),
    matches,
  }
}

// ─── normalise DB rows to app shape ──────────────────────────────────────────
const normalPlayer   = r => ({ id: r.id, name: r.name })
const normalFineType = r => ({ id: r.id, name: r.name, cost: Number(r.cost) })
const normalSeason   = r => ({ id: r.id, name: r.name, type: r.type })
const normalFine     = r => ({
  id: r.id, matchId: r.match_id, playerId: r.player_id,
  fineTypeId: r.fine_type_id, playerName: r.player_name,
  fineName: r.fine_name, cost: Number(r.cost), paid: r.paid,
})
const normalSub = r => ({
  id: r.id, matchId: r.match_id, playerId: r.player_id,
  playerName: r.player_name, amount: Number(r.amount), paid: r.paid,
})

// ─── PLAYERS ─────────────────────────────────────────────────────────────────
export async function addPlayer(player) {
  return normalPlayer(handle(await supabase.from('players').insert({ id: player.id, name: player.name }).select().single()))
}

export async function updatePlayer(player) {
  return normalPlayer(handle(await supabase.from('players').update({ name: player.name }).eq('id', player.id).select().single()))
}

export async function deletePlayer(id) {
  handle(await supabase.from('players').delete().eq('id', id))
}

// ─── FINE TYPES ───────────────────────────────────────────────────────────────
export async function addFineType(ft) {
  return normalFineType(handle(await supabase.from('fine_types').insert({ id: ft.id, name: ft.name, cost: ft.cost }).select().single()))
}

export async function updateFineType(ft) {
  return normalFineType(handle(await supabase.from('fine_types').update({ name: ft.name, cost: ft.cost }).eq('id', ft.id).select().single()))
}

export async function deleteFineType(id) {
  handle(await supabase.from('fine_types').delete().eq('id', id))
}

// ─── SEASONS ──────────────────────────────────────────────────────────────────
export async function addSeason(season) {
  return normalSeason(handle(await supabase.from('seasons').insert({ id: season.id, name: season.name, type: season.type }).select().single()))
}

export async function updateSeason(season) {
  return normalSeason(handle(await supabase.from('seasons').update({ name: season.name, type: season.type }).eq('id', season.id).select().single()))
}

export async function deleteSeason(id) {
  handle(await supabase.from('seasons').delete().eq('id', id))
}

// ─── MATCHES ──────────────────────────────────────────────────────────────────
export async function addMatch(match) {
  const row = handle(await supabase.from('matches').insert({
    id: match.id, date: match.date, season_id: match.seasonId || null,
    opponent: match.opponent, submitted: match.submitted,
  }).select().single())
  return { ...match, ...row, seasonId: row.season_id }
}

export async function updateMatch(id, patch) {
  if ('date' in patch || 'seasonId' in patch || 'opponent' in patch || 'submitted' in patch) {
    handle(await supabase.from('matches').update({
      ...(patch.date !== undefined ? { date: patch.date } : {}),
      ...(patch.seasonId !== undefined ? { season_id: patch.seasonId || null } : {}),
      ...(patch.opponent !== undefined ? { opponent: patch.opponent } : {}),
      ...(patch.submitted !== undefined ? { submitted: patch.submitted } : {}),
    }).eq('id', id))
  }

  if ('playerIds' in patch) {
    handle(await supabase.from('match_players').delete().eq('match_id', id))
    if (patch.playerIds?.length) {
      handle(await supabase.from('match_players').insert(
        patch.playerIds.map(pid => ({ match_id: id, player_id: pid }))
      ))
    }
  }

  if ('fines' in patch) {
    handle(await supabase.from('fines').delete().eq('match_id', id))
    if (patch.fines?.length) {
      handle(await supabase.from('fines').insert(
        patch.fines.map(f => ({
          id: f.id, match_id: id, player_id: f.playerId || null,
          fine_type_id: f.fineTypeId || null, player_name: f.playerName,
          fine_name: f.fineName, cost: f.cost, paid: f.paid,
        }))
      ))
    }
  }

  if ('subs' in patch) {
    handle(await supabase.from('subs').delete().eq('match_id', id))
    if (patch.subs?.length) {
      handle(await supabase.from('subs').insert(
        patch.subs.map(s => ({
          id: s.id, match_id: id, player_id: s.playerId || null,
          player_name: s.playerName, amount: s.amount, paid: s.paid,
        }))
      ))
    }
  }
}

export async function deleteMatch(id) {
  // Cascades via FK constraints (set up in schema.sql)
  handle(await supabase.from('matches').delete().eq('id', id))
}

// ─── BULK IMPORT (from JSON backup) ──────────────────────────────────────────
export async function importAll({ players, fineTypes, seasons, matches }) {
  // Clear everything first
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
  if (players.length)   handle(await supabase.from('players').insert(players.map(p => ({ id: p.id, name: p.name }))))
  if (fineTypes.length) handle(await supabase.from('fine_types').insert(fineTypes.map(f => ({ id: f.id, name: f.name, cost: f.cost }))))
  if (seasons.length)   handle(await supabase.from('seasons').insert(seasons.map(s => ({ id: s.id, name: s.name, type: s.type }))))

  for (const m of matches) {
    handle(await supabase.from('matches').insert({ id: m.id, date: m.date, season_id: m.seasonId, opponent: m.opponent, submitted: m.submitted }))
    if (m.playerIds?.length) handle(await supabase.from('match_players').insert(m.playerIds.map(pid => ({ match_id: m.id, player_id: pid }))))
    if (m.fines?.length)     handle(await supabase.from('fines').insert(m.fines.map(f => ({ id: f.id, match_id: m.id, player_id: f.playerId, fine_type_id: f.fineTypeId, player_name: f.playerName, fine_name: f.fineName, cost: f.cost, paid: f.paid }))))
    if (m.subs?.length)      handle(await supabase.from('subs').insert(m.subs.map(s => ({ id: s.id, match_id: m.id, player_id: s.playerId, player_name: s.playerName, amount: s.amount, paid: s.paid }))))
  }
}
