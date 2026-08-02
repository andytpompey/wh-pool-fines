import { createClient } from 'npm:@supabase/supabase-js@2'
import Stripe from 'npm:stripe@18'

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('PUBLIC_APP_ORIGIN') ?? '',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, idempotency-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ message: 'Method not allowed' }, 405)

  const authorization = request.headers.get('Authorization')
  const idempotencyKey = request.headers.get('Idempotency-Key')
  if (!authorization?.startsWith('Bearer ')) return json({ message: 'Authentication required' }, 401)
  if (!idempotencyKey || !/^[a-zA-Z0-9_-]{16,255}$/.test(idempotencyKey)) {
    return json({ message: 'A valid idempotency key is required' }, 400)
  }

  const supabaseURL = Deno.env.get('SUPABASE_URL')
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
  const publicOrigin = Deno.env.get('PUBLIC_APP_ORIGIN')
  if (!supabaseURL || !publishableKey || !serviceRoleKey || !stripeKey || !publicOrigin) {
    return json({ message: 'Checkout is not configured' }, 503)
  }

  const userClient = createClient(supabaseURL, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const admin = createClient(supabaseURL, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: userData } = await userClient.auth.getUser()
  if (!userData.user) return json({ message: 'Authentication required' }, 401)

  let body: { teamId?: string; playingCycleId?: string; offeringCode?: string }
  try { body = await request.json() } catch { return json({ message: 'Invalid JSON body' }, 400) }
  if (!body.teamId || !body.playingCycleId) return json({ message: 'Team and playing cycle are required' }, 400)

  const requestHash = await sha256(`${userData.user.id}:${body.teamId}`)
  const windowStartedAt = new Date(Math.floor(Date.now() / 600_000) * 600_000).toISOString()
  const { data: currentLimit } = await admin.from('public_request_limits').select('request_count')
    .eq('request_hash', requestHash).eq('request_kind', 'commercial_checkout').eq('window_started_at', windowStartedAt).maybeSingle()
  if ((currentLimit?.request_count ?? 0) >= 5) return json({ message: 'Too many checkout attempts. Wait a few minutes and try again.' }, 429)
  const limitResult = await admin.from('public_request_limits').upsert({
    request_hash: requestHash, request_kind: 'commercial_checkout', window_started_at: windowStartedAt,
    request_count: (currentLimit?.request_count ?? 0) + 1,
  }, { onConflict: 'request_hash,request_kind,window_started_at' })
  if (limitResult.error) return json({ message: 'Checkout is temporarily unavailable' }, 503)

  const { data: membership } = await admin.from('team_memberships').select('role, status, players!inner(user_id)')
    .eq('team_id', body.teamId).eq('players.user_id', userData.user.id).eq('status', 'active').maybeSingle()
  if (!membership || !['captain', 'vice_captain', 'admin'].includes(membership.role)) {
    return json({ message: 'Team leadership access required' }, 403)
  }
  const { data: cycle } = await admin.from('team_playing_cycles').select('id, name, sport, team_id, starts_on, ends_on, status')
    .eq('id', body.playingCycleId).eq('team_id', body.teamId).maybeSingle()
  if (!cycle) return json({ message: 'Playing cycle is unavailable' }, 404)
  if (!cycle.starts_on || !cycle.ends_on) return json({ message: 'Set the playing-cycle dates before checkout' }, 409)
  if (['abandoned', 'cancelled'].includes(cycle.status)) return json({ message: 'This playing cycle cannot be purchased' }, 409)
  const { data: team } = await admin.from('teams').select('name').eq('id', body.teamId).single()
  if (!team) return json({ message: 'Team is unavailable' }, 404)

  const offeringCode = body.offeringCode ?? 'team-season-standard'
  const now = new Date().toISOString()
  const { data: offering } = await admin.from('commercial_offerings')
    .select('id, code, version, renewal_behaviour, commercial_price_versions!inner(id, amount_minor, currency, provider_price_refs, effective_from, effective_to, state)')
    .eq('code', offeringCode).eq('state', 'published').contains('sales_channels', ['web'])
    .eq('commercial_price_versions.state', 'published').lte('commercial_price_versions.effective_from', now)
    .order('version', { ascending: false }).order('effective_from', { referencedTable: 'commercial_price_versions', ascending: false })
    .limit(1).limit(1, { referencedTable: 'commercial_price_versions' }).maybeSingle()
  const price = offering?.commercial_price_versions?.[0]
  if (!offering || !price || (price.effective_to && price.effective_to <= now)) {
    return json({ message: 'No purchasable offer is currently available' }, 409)
  }
  const stripePriceId = price.provider_price_refs?.stripe
  if (!stripePriceId) return json({ message: 'The web price is awaiting payment-provider activation' }, 503)

  const { data: existingEntitlement } = await admin.from('team_season_entitlements').select('id, valid_until, grace_until, revoked_at')
    .eq('team_id', body.teamId).eq('playing_cycle_id', body.playingCycleId).is('revoked_at', null)
    .order('valid_until', { ascending: false }).limit(1).maybeSingle()
  if (existingEntitlement && new Date(existingEntitlement.grace_until ?? existingEntitlement.valid_until) >= new Date()) {
    return json({ message: 'This team season already has access' }, 409)
  }

  let { data: customer } = await admin.from('billing_customers').select('*')
    .eq('owner_user_id', userData.user.id).eq('team_id', body.teamId).maybeSingle()
  const stripe = new Stripe(stripeKey)
  if (!customer) {
    const stripeCustomer = await stripe.customers.create({ email: userData.user.email, metadata: { roobin_user_id: userData.user.id, roobin_team_id: body.teamId } }, { idempotencyKey: `${idempotencyKey}-customer` })
    const result = await admin.from('billing_customers').insert({
      owner_user_id: userData.user.id, customer_type: 'team', team_id: body.teamId,
      provider_customer_refs: { stripe: stripeCustomer.id }, billing_email: userData.user.email,
    }).select().single()
    if (result.error) return json({ message: 'Billing customer could not be created' }, 503)
    customer = result.data
  }
  const stripeCustomerId = customer.provider_customer_refs?.stripe
  if (!stripeCustomerId) return json({ message: 'Billing customer requires support' }, 409)

  const session = await stripe.checkout.sessions.create({
    mode: offering.renewal_behaviour === 'automatic' ? 'subscription' : 'payment',
    customer: stripeCustomerId,
    line_items: [{ price: stripePriceId, quantity: 1 }],
    automatic_tax: { enabled: true },
    allow_promotion_codes: true,
    custom_text: { submit: { message: `${team.name} — ${cycle.sport}, ${cycle.name}, ${cycle.starts_on} to ${cycle.ends_on}. ${offering.renewal_behaviour === 'automatic' ? 'Renews automatically under the displayed terms until cancelled.' : 'One playing-cycle purchase; it does not renew automatically.'} Tax and total are shown above before payment.` } },
    ...(offering.renewal_behaviour === 'automatic' ? {} : { invoice_creation: { enabled: true } }),
    client_reference_id: `${body.teamId}:${body.playingCycleId}`,
    metadata: {
      roobin_team_id: body.teamId, roobin_playing_cycle_id: body.playingCycleId,
      roobin_coverage_start: cycle.starts_on, roobin_coverage_end: cycle.ends_on,
      roobin_offering_id: offering.id, roobin_price_version_id: price.id,
      roobin_billing_customer_id: customer.id,
    },
    success_url: `${publicOrigin}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${publicOrigin}/teams/${body.teamId}?billing=cancelled`,
  }, { idempotencyKey })

  return json({ checkoutUrl: session.url }, 200)
})

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  })
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))
  return Array.from(new Uint8Array(digest)).map(byte => byte.toString(16).padStart(2, '0')).join('')
}
