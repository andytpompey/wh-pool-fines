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
  role: 'member',
  createdAt: row.created_at,
  updatedAt: row.updated_at ?? row.created_at,
}) : null

export async function getCurrentUserProfile(userId) {
  if (!userId) return null
  const row = handle(await supabase.from('players').select('*').eq('user_id', userId).maybeSingle())
  return normaliseProfile(row)
}

export async function findPlayerMatchForUser({ email, mobile }) {
  const normalisedEmail = email?.trim().toLowerCase()
  const normalisedMobile = mobile?.trim()
  if (!normalisedEmail && !normalisedMobile) return null

  if (normalisedEmail) {
    const byEmail = handle(await supabase.from('players').select('*').ilike('email', normalisedEmail).limit(1).maybeSingle())
    if (byEmail) return byEmail
  }
  if (normalisedMobile) {
    const byMobile = handle(await supabase.from('players').select('*').eq('mobile', normalisedMobile).limit(1).maybeSingle())
    if (byMobile) return byMobile
  }

  return null
}

export async function upsertCurrentUserProfile({ user }) {
  if (!user?.id) throw new Error('Authenticated user is required')

  const linkedPlayer = await getCurrentUserProfile(user.id)
  if (linkedPlayer) return linkedPlayer

  const email = user.email?.trim().toLowerCase() ?? null
  const mobile = user.phone?.trim() ?? null

  const playerMatch = await findPlayerMatchForUser({ email, mobile })
  if (playerMatch) {
    const row = handle(await supabase.from('players').update({ user_id: user.id }).eq('id', playerMatch.id).select().single())
    return normaliseProfile(row)
  }

  if (!email) return null

  const inserted = handle(await supabase.from('players').insert({
    email,
    user_id: user.id,
    name: user.user_metadata?.name ?? email.split('@')[0],
    display_name: user.user_metadata?.name ?? email.split('@')[0],
    mobile,
    preferred_auth_method: mobile ? 'whatsapp' : 'email',
    receive_team_notifications: true,
  }).select().single())

  return normaliseProfile(inserted)
}

export async function ensureCurrentUserPlayer({ user }) {
  const profile = await upsertCurrentUserProfile({ user })
  if (!profile?.playerId) throw new Error('Unable to resolve player profile for this user.')
  return {
    id: profile.playerId,
    email: profile.email,
    displayName: profile.displayName,
  }
}

export async function updateCurrentUserProfile(userId, updates) {
  if (!userId) throw new Error('Authenticated user is required')

  const existing = handle(await supabase.from('players').select('*').eq('user_id', userId).maybeSingle())
  if (!existing) return null

  if ('playerId' in updates) {
    const targetPlayerId = updates.playerId || null
    if (existing?.id && existing.id !== targetPlayerId) {
      await handle(await supabase.from('players').update({ user_id: null }).eq('id', existing.id))
    }

    if (targetPlayerId) {
      const row = handle(await supabase.from('players').update({ user_id: userId }).eq('id', targetPlayerId).select().single())
      return normaliseProfile(row)
    }

    return null
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

  if (!Object.keys(payload).length) {
    return normaliseProfile(existing)
  }

  const row = handle(await supabase.from('players').update(payload).eq('id', existing.id).select().single())
  return normaliseProfile(row)
}
