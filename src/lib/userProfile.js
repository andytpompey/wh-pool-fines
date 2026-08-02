import { supabase } from './supabase'

function handle(result) {
  if (result.error) throw result.error
  return result.data
}

const normaliseProfile = row => row ? ({
  id: row.user_id,
  email: row.email ?? '',
  mobile: row.mobile ?? '',
  preferredAuthMethod: row.preferred_auth_method ?? 'email',
  playerId: row.id,
  displayName: row.display_name ?? row.name ?? '',
  receiveTeamNotifications: Boolean(row.receive_team_notifications),
  dashboardSeasonPreferences: row.dashboard_season_preferences ?? {},
  role: 'member',
  createdAt: row.created_at,
  updatedAt: row.updated_at ?? row.created_at,
}) : null

export async function getCurrentUserProfile(userId) {
  if (!userId) return null
  const row = handle(await supabase.from('players').select('*').eq('user_id', userId).maybeSingle())
  return normaliseProfile(row)
}

export async function upsertCurrentUserProfile({ user, displayName = null, mobile = null, preferredAuthMethod = null }) {
  if (!user?.id) throw new Error('Authenticated user is required')

  const row = handle(await supabase.rpc('ensure_current_player', {
    profile_display_name: displayName ?? user.user_metadata?.name ?? null,
    profile_mobile: mobile ?? user.phone ?? null,
    profile_preferred_auth_method: preferredAuthMethod,
  }))
  return normaliseProfile(row)
}

export async function ensureCurrentUserPlayer({ user, displayName = null, mobile = null, preferredAuthMethod = null }) {
  const profile = await upsertCurrentUserProfile({ user, displayName, mobile, preferredAuthMethod })
  if (!profile?.playerId) throw new Error('Unable to resolve player profile for this user.')
  return {
    id: profile.playerId,
    email: profile.email,
    displayName: profile.displayName,
  }
}

export async function updateCurrentUserProfile(userId, updates) {
  if (!userId) throw new Error('Authenticated user is required')

  let existing = handle(await supabase.from('players').select('*').eq('user_id', userId).maybeSingle())
  if (!existing) return null

  if ('playerId' in updates) {
    const targetPlayerId = updates.playerId || null
    if (existing?.id !== targetPlayerId) {
      await handle(await supabase.from('players').update({ user_id: null, auth_user_id: null }).eq('id', existing.id))

      if (!targetPlayerId) return null

      existing = handle(await supabase.from('players').update({ user_id: userId, auth_user_id: userId }).eq('id', targetPlayerId).select().single())
    }
  }

  const payload = {}
  if ('displayName' in updates) {
    const displayName = updates.displayName?.trim()
    if (!displayName) throw new Error('Display name is required.')
    payload.display_name = displayName
    payload.name = displayName
  }
  if ('receiveTeamNotifications' in updates) {
    payload.receive_team_notifications = Boolean(updates.receiveTeamNotifications)
  }
  if ('preferredAuthMethod' in updates) {
    payload.preferred_auth_method = updates.preferredAuthMethod
  }
  if ('dashboardSeasonPreferences' in updates) {
    payload.dashboard_season_preferences = updates.dashboardSeasonPreferences ?? {}
  }

  if (!Object.keys(payload).length) {
    return normaliseProfile(existing)
  }

  const row = handle(await supabase.from('players').update(payload).eq('id', existing.id).select().single())
  return normaliseProfile(row)
}
