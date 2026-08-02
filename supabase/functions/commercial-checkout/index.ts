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

  let body: { teamId?: string; seasonId?: string; offeringCode?: string }
  try { body = await request.json() } catch { return json({ message: 'Invalid JSON body' }, 400) }
  if (!body.teamId || !body.seasonId) return json({ message: 'Team and season are required' }, 400)

  const { data: membership } = await admin.from('team_memberships').select('role, status, players!inner(user_id)')
    .eq('team_id', body.teamId).eq('players.user_id', userData.user.id).eq('status', 'active').maybeSingle()
  if (!membership || !['captain', 'vice_captain', 'admin'].includes(membership.role)) {
    return json({ message: 'Team leadership access required' }, 403)
  }
  const { data: season } = await admin.from('seasons').select('id, name, team_id').eq('id', body.seasonId).eq('team_id', body.teamId).maybeSingle()
  if (!season) return json({ message: 'Season is unavailable' }, 404)

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
    .eq('team_id', body.teamId).eq('season_id', body.seasonId).is('revoked_at', null)
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
    client_reference_id: `${body.teamId}:${body.seasonId}`,
    metadata: {
      roobin_team_id: body.teamId, roobin_season_id: body.seasonId,
      roobin_offering_id: offering.id, roobin_price_version_id: price.id,
      roobin_billing_customer_id: customer.id,
    },
    success_url: `${publicOrigin}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${publicOrigin}/teams/${body.teamId}/billing?cancelled=1`,
  }, { idempotencyKey })

  return json({ checkoutUrl: session.url }, 200)
})

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  })
}
