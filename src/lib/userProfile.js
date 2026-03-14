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
  role: 'member',
  createdAt: row.created_at,
  updatedAt: row.created_at,
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
  if (!playerMatch) return null

  const row = handle(await supabase.from('players').update({
    user_id: user.id,
  }).eq('id', playerMatch.id).select().single())

  return normaliseProfile(row)
}

export async function updateCurrentUserProfile(userId, updates) {
  if (!userId) throw new Error('Authenticated user is required')
  if (!('playerId' in updates)) {
    return getCurrentUserProfile(userId)
  }

  const targetPlayerId = updates.playerId || null
  const existing = handle(await supabase.from('players').select('id').eq('user_id', userId).maybeSingle())

  if (existing?.id && existing.id !== targetPlayerId) {
    await handle(await supabase.from('players').update({ user_id: null }).eq('id', existing.id))
  }

  if (targetPlayerId) {
    const row = handle(await supabase.from('players').update({ user_id: userId }).eq('id', targetPlayerId).select().single())
    return normaliseProfile(row)
  }

  return null
}
