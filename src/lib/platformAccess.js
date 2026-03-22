import { supabase } from './supabase'
import { PLATFORM_ROLE } from './permissions'

function handle(result) {
  if (result.error) throw result.error
  return result.data
}

export async function ensureAppUser(userId) {
  if (!userId) return null
  const existing = handle(await supabase.from('app_users').select('*').eq('id', userId).maybeSingle())
  if (existing) return existing
  return handle(await supabase.from('app_users').insert({ id: userId }).select('*').single())
}

export async function getPlatformAccess(userId) {
  if (!userId) return { platformRole: null, isPlatformAdmin: false }
  const appUser = await ensureAppUser(userId)
  const isPlatformAdmin = Boolean(appUser?.is_platform_admin)
  return {
    appUser,
    platformRole: isPlatformAdmin ? PLATFORM_ROLE.ADMIN : null,
    isPlatformAdmin,
  }
}
