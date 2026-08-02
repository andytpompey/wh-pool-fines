import { supabase } from './supabase'

export async function getPublishedTeamSeasonOffer() {
  const now = new Date().toISOString()
  const { data, error } = await supabase.from('commercial_offerings')
    .select('id, code, version, renewal_behaviour, commercial_products(name, description), commercial_price_versions(id, amount_minor, currency, tax_behaviour, effective_from, effective_to, state)')
    .eq('code', 'team-season-standard').eq('state', 'published')
    .eq('commercial_price_versions.state', 'published')
    .lte('commercial_price_versions.effective_from', now)
    .order('version', { ascending: false })
    .order('effective_from', { referencedTable: 'commercial_price_versions', ascending: false })
    .limit(1).limit(1, { referencedTable: 'commercial_price_versions' }).maybeSingle()
  if (error) throw error
  const price = data?.commercial_price_versions?.find(item => !item.effective_to || item.effective_to > now)
  return data && price ? { ...data, price } : null
}

export async function getTeamEntitlements(teamId, seasons) {
  if (!teamId || !seasons?.length) return []
  const results = await Promise.all(seasons.map(async season => {
    const { data, error } = await supabase.rpc('current_team_season_entitlement', {
      target_team_id: teamId,
      target_season_id: season.id,
    })
    if (error) throw error
    return { season, ...(data ?? { state: 'missing', capabilities: {} }) }
  }))
  return results
}

export async function createTeamSeasonCheckout({ teamId, seasonId }) {
  const idempotencyKey = crypto.randomUUID().replaceAll('-', '')
  const { data, error } = await supabase.functions.invoke('commercial-checkout', {
    body: { teamId, seasonId, offeringCode: 'team-season-standard' },
    headers: { 'Idempotency-Key': idempotencyKey },
  })
  if (error) throw error
  if (!data?.checkoutUrl) throw new Error('Checkout did not return a secure payment page.')
  return data.checkoutUrl
}

export function formatMoney(amountMinor, currency = 'GBP') {
  return new Intl.NumberFormat('en-GB', { style: 'currency', currency }).format(amountMinor / 100)
}
