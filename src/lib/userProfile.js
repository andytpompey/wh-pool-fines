import { supabase } from './supabase'

function handle(result) {
  if (result.error) throw result.error
  return result.data
}

const normaliseProfile = row => row ? ({
  id: row.id,
  email: row.email ?? '',
  mobile: row.mobile ?? '',
  preferredAuthMethod: row.preferred_auth_method ?? 'email',
  playerId: row.player_id ?? null,
  role: row.role ?? 'member',
  createdAt: row.created_at,
  updatedAt: row.updated_at,
}) : null

export async function getCurrentUserProfile(userId) {
  if (!userId) return null
  const row = handle(await supabase.from('app_users').select('*').eq('id', userId).maybeSingle())
  return normaliseProfile(row)
}

export async function findPlayerMatchForUser({ email, mobile }) {
  const normalisedEmail = email?.trim().toLowerCase()
  const normalisedMobile = mobile?.trim()
  if (!normalisedEmail && !normalisedMobile) return null

  // Optional best-effort linking for projects that still have legacy contact columns on players.
  try {
    if (normalisedEmail) {
      const byEmail = handle(await supabase.from('players').select('id,name').ilike('email', normalisedEmail).limit(1).maybeSingle())
      if (byEmail) return byEmail
    }
    if (normalisedMobile) {
      const byMobile = handle(await supabase.from('players').select('id,name').eq('mobile', normalisedMobile).limit(1).maybeSingle())
      if (byMobile) return byMobile
    }
  } catch {
    // Ignore if legacy columns are not present.
  }

  return null
}

export async function upsertCurrentUserProfile({ user, preferredAuthMethod = 'email', playerId = null }) {
  if (!user?.id) throw new Error('Authenticated user is required')

  const email = user.email?.trim().toLowerCase() ?? null
  const mobile = user.phone?.trim() ?? null

  const playerMatch = await findPlayerMatchForUser({ email, mobile })
  const resolvedPlayerId = playerId ?? playerMatch?.id ?? null

  const row = handle(await supabase.from('app_users').upsert({
    id: user.id,
    email,
    mobile,
    preferred_auth_method: preferredAuthMethod,
    player_id: resolvedPlayerId,
  }).select().single())

  return normaliseProfile(row)
}

export async function updateCurrentUserProfile(userId, updates) {
  if (!userId) throw new Error('Authenticated user is required')

  const payload = {}
  if ('preferredAuthMethod' in updates) payload.preferred_auth_method = updates.preferredAuthMethod
  if ('playerId' in updates) payload.player_id = updates.playerId || null

  const emailForValidation = updates.email ?? updates.currentEmail
  const mobileForValidation = updates.mobile ?? updates.currentMobile

  if (payload.preferred_auth_method === 'email' && !emailForValidation) {
    throw new Error('Email is required when default method is Email.')
  }
  if (payload.preferred_auth_method === 'whatsapp' && !mobileForValidation) {
    throw new Error('Mobile number is required when default method is WhatsApp.')
  }

  const row = handle(await supabase.from('app_users').update(payload).eq('id', userId).select().single())
  return normaliseProfile(row)
}
