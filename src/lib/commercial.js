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

export async function getTeamPlayingCycles(teamId) {
  if (!teamId) return []
  const { data, error } = await supabase.from('team_playing_cycles')
    .select('id, team_id, name, sport, starts_on, ends_on, status, source')
    .eq('team_id', teamId).order('starts_on', { ascending: false, nullsFirst: false }).order('name')
  if (error) throw error
  return (data ?? []).map(row => ({
    id: row.id, teamId: row.team_id, name: row.name, sport: row.sport,
    startsOn: row.starts_on, endsOn: row.ends_on, status: row.status, source: row.source,
  }))
}

export async function getTeamEntitlements(teamId, cycles) {
  if (!teamId || !cycles?.length) return []
  const results = await Promise.all(cycles.map(async cycle => {
    const { data, error } = await supabase.rpc('current_team_cycle_entitlement', {
      target_team_id: teamId,
      target_playing_cycle_id: cycle.id,
    })
    if (error) throw error
    return { cycle, ...(data ?? { state: 'missing', capabilities: {} }) }
  }))
  return results
}

export async function createTeamSeasonCheckout({ teamId, playingCycleId }) {
  const idempotencyKey = crypto.randomUUID().replaceAll('-', '')
  const { data, error } = await supabase.functions.invoke('commercial-checkout', {
    body: { teamId, playingCycleId, offeringCode: 'team-season-standard' },
    headers: { 'Idempotency-Key': idempotencyKey },
  })
  if (error) throw error
  if (!data?.checkoutUrl) throw new Error('Checkout did not return a secure payment page.')
  return data.checkoutUrl
}

export async function updatePlayingCycle(cycle) {
  const { data, error } = await supabase.from('team_playing_cycles').update({
    name: cycle.name.trim(), sport: cycle.sport, starts_on: cycle.startsOn || null,
    ends_on: cycle.endsOn || null, status: cycle.status, updated_at: new Date().toISOString(),
  }).eq('id', cycle.id).eq('team_id', cycle.teamId).select().single()
  if (error) throw error
  return data
}

export async function openBillingPortal(teamId) {
  const { data, error } = await supabase.functions.invoke('commercial-portal', { body: { teamId } })
  if (error) throw error
  if (!data?.portalUrl) throw new Error('Billing portal did not return a secure URL.')
  window.location.assign(data.portalUrl)
}

export function formatMoney(amountMinor, currency = 'GBP') {
  return new Intl.NumberFormat('en-GB', { style: 'currency', currency }).format(amountMinor / 100)
}

export async function getCommercialAdminDashboard() {
  const { data, error } = await supabase.rpc('get_commercial_admin_dashboard')
  if (error) throw error
  if (!data) throw new Error('Platform administrator access is required.')
  return data
}

export async function setCommercialEnforcement(mode, reason) {
  const { data, error } = await supabase.rpc('set_commercial_enforcement', {
    new_mode: mode,
    change_reason: reason,
  })
  if (error) throw error
  return data
}

export async function scheduleCommercialPrice(input) {
  const { data, error } = await supabase.rpc('schedule_commercial_price', {
    target_offering_id: input.offeringId,
    new_amount_minor: Math.round(Number(input.amountPounds) * 100),
    new_currency: input.currency,
    new_tax_behaviour: input.taxBehaviour,
    new_market: input.market,
    new_effective_from: new Date(input.effectiveFrom).toISOString(),
    new_effective_to: input.effectiveTo ? new Date(input.effectiveTo).toISOString() : null,
    existing_subscription_treatment: input.subscriptionTreatment,
    approval_reason: input.reason,
  })
  if (error) throw error
  return data
}

export async function createCommercialDiscount(input) {
  const { data, error } = await supabase.rpc('create_commercial_discount', {
    discount_name: input.name,
    discount_type: input.type,
    discount_value: Number(input.value),
    discount_currency: input.currency,
    valid_from: new Date(input.validFrom).toISOString(),
    valid_until: input.validUntil ? new Date(input.validUntil).toISOString() : null,
    total_limit: input.totalLimit ? Number(input.totalLimit) : null,
    per_customer_limit: input.perCustomerLimit ? Number(input.perCustomerLimit) : 1,
    eligibility: {},
    provider_refs: {},
    approval_reason: input.reason,
  })
  if (error) throw error
  return data
}

export async function cloneCommercialOffering(offeringId, code, reason) {
  const { data, error } = await supabase.rpc('clone_commercial_offering', { source_offering_id: offeringId, new_code: code, reason })
  if (error) throw error
  return data
}

export async function publishCommercialOffering(offeringId, reason) {
  const { data, error } = await supabase.rpc('publish_commercial_offering', { target_offering_id: offeringId, approval_reason: reason })
  if (error) throw error
  return data
}

export async function retireCommercialOffering(offeringId, reason) {
  const { data, error } = await supabase.rpc('retire_commercial_offering', { target_offering_id: offeringId, retirement_reason: reason })
  if (error) throw error
  return data
}

export async function updateDraftCommercialOffering(offeringId, changes, reason) {
  const { data, error } = await supabase.rpc('update_draft_commercial_offering', { target_offering_id: offeringId, changes, reason })
  if (error) throw error
  return data
}

export async function getSupportAdminQueue() {
  const { data, error } = await supabase.rpc('get_support_admin_queue')
  if (error) throw error
  return data ?? []
}

export async function updateSupportCase(input) {
  const { data, error } = await supabase.rpc('update_support_case', {
    target_case_id: input.caseId, new_status: input.status, new_priority: input.priority,
    customer_message: input.customerMessage || '', internal_note: input.internalNote || '', reason: input.reason,
  })
  if (error) throw error
  return data
}

export async function issueCommercialDiscountCode(discountId, reason, code = '') {
  const { data, error } = await supabase.functions.invoke('commercial-discounts', { body: { discountId, reason, code: code || undefined, maxRedemptions: 1 } })
  if (error) throw error
  if (!data?.code) throw new Error('Discount code was not returned.')
  return data
}
