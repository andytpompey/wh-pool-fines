import { createClient } from 'npm:@supabase/supabase-js@2'
import Stripe from 'npm:stripe@18'

Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')
  const supabaseURL = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!stripeKey || !webhookSecret || !supabaseURL || !serviceRoleKey) return new Response('Unavailable', { status: 503 })

  const rawBody = await request.text()
  const signature = request.headers.get('stripe-signature')
  if (!signature) return new Response('Missing signature', { status: 400 })
  const stripe = new Stripe(stripeKey)
  let event: Stripe.Event
  try { event = await stripe.webhooks.constructEventAsync(rawBody, signature, webhookSecret) }
  catch { return new Response('Invalid signature', { status: 400 }) }

  const admin = createClient(supabaseURL, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } })
  const ingress = await admin.from('commercial_events').insert({
    provider: 'stripe', provider_event_id: event.id, event_type: event.type,
    payload: event as unknown as Record<string, unknown>, status: 'received', attempts: 1,
  }).select('id').maybeSingle()
  if (ingress.error?.code === '23505') return new Response(JSON.stringify({ received: true, duplicate: true }), { status: 200 })
  if (ingress.error || !ingress.data) return new Response('Event persistence failed', { status: 503 })

  try {
    if (event.type === 'checkout.session.completed') {
      await fulfilCheckout(admin, event.data.object as Stripe.Checkout.Session)
    } else if (event.type === 'invoice.paid' || event.type === 'invoice.payment_failed' || event.type.startsWith('customer.subscription.')) {
      await reconcileSubscription(admin, stripe, event)
    }
    await admin.from('commercial_events').update({ status: 'processed', processed_at: new Date().toISOString() }).eq('id', ingress.data.id)
  } catch (error) {
    await admin.from('commercial_events').update({ status: 'failed', error_code: safeErrorCode(error) }).eq('id', ingress.data.id)
    return new Response('Processing failed', { status: 503 })
  }
  return new Response(JSON.stringify({ received: true }), { status: 200, headers: { 'Content-Type': 'application/json' } })
})

async function fulfilCheckout(admin: ReturnType<typeof createClient>, session: Stripe.Checkout.Session) {
  if (session.payment_status !== 'paid' && session.mode !== 'subscription') throw new Error('checkout_unpaid')
  const meta = session.metadata ?? {}
  const required = ['roobin_team_id', 'roobin_season_id', 'roobin_offering_id', 'roobin_price_version_id', 'roobin_billing_customer_id']
  if (required.some(key => !meta[key])) throw new Error('checkout_metadata_invalid')
  const { data: offering } = await admin.from('commercial_offerings').select('entitlement_definition_id').eq('id', meta.roobin_offering_id).single()
  if (!offering) throw new Error('offering_missing')
  const start = new Date()
  const end = new Date(start)
  end.setUTCFullYear(end.getUTCFullYear() + 1)
  const providerSubscriptionId = typeof session.subscription === 'string' ? session.subscription : null
  const subscriptionResult = await admin.from('commercial_subscriptions').upsert({
    billing_customer_id: meta.roobin_billing_customer_id,
    offering_id: meta.roobin_offering_id,
    price_version_id: meta.roobin_price_version_id,
    team_id: meta.roobin_team_id,
    season_id: meta.roobin_season_id,
    provider: 'stripe',
    provider_subscription_id: providerSubscriptionId ?? `checkout:${session.id}`,
    state: 'active', current_period_start: start.toISOString(), current_period_end: end.toISOString(),
    metadata: { checkout_session_id: session.id, payment_intent_id: session.payment_intent },
  }, { onConflict: 'provider,provider_subscription_id' }).select('id').single()
  if (subscriptionResult.error) throw subscriptionResult.error
  const entitlementResult = await admin.from('team_season_entitlements').upsert({
    team_id: meta.roobin_team_id, season_id: meta.roobin_season_id,
    subscription_id: subscriptionResult.data.id, entitlement_definition_id: offering.entitlement_definition_id,
    state: 'active', valid_from: start.toISOString(), valid_until: end.toISOString(),
    source: 'purchase', source_reference: `stripe:${session.id}`,
  }, { onConflict: 'team_id,season_id,entitlement_definition_id,subscription_id' })
  if (entitlementResult.error) throw entitlementResult.error
}

async function reconcileSubscription(admin: ReturnType<typeof createClient>, stripe: Stripe, event: Stripe.Event) {
  let subscriptionId: string | null = null
  if (event.type.startsWith('customer.subscription.')) subscriptionId = (event.data.object as Stripe.Subscription).id
  else {
    const invoice = event.data.object as Stripe.Invoice
    subscriptionId = typeof invoice.parent?.subscription_details?.subscription === 'string'
      ? invoice.parent.subscription_details.subscription : null
  }
  if (!subscriptionId) return
  const remote = await stripe.subscriptions.retrieve(subscriptionId)
  const state = remote.status === 'active' || remote.status === 'trialing' ? remote.status
    : remote.status === 'past_due' || remote.status === 'unpaid' ? 'past_due'
      : remote.status === 'paused' ? 'paused' : remote.status === 'canceled' ? 'cancelled' : 'expired'
  const item = remote.items.data[0]
  const update = await admin.from('commercial_subscriptions').update({
    state, current_period_start: new Date(item.current_period_start * 1000).toISOString(),
    current_period_end: new Date(item.current_period_end * 1000).toISOString(),
    cancel_at_period_end: remote.cancel_at_period_end,
    cancelled_at: remote.canceled_at ? new Date(remote.canceled_at * 1000).toISOString() : null,
  }).eq('provider', 'stripe').eq('provider_subscription_id', subscriptionId).select('id').maybeSingle()
  if (update.error) throw update.error
  if (update.data) {
    await admin.from('team_season_entitlements').update({
      state: state === 'active' || state === 'trialing' ? (state === 'trialing' ? 'trial' : 'active') : state === 'past_due' ? 'grace' : 'expired',
      valid_until: new Date(item.current_period_end * 1000).toISOString(), updated_at: new Date().toISOString(),
    }).eq('subscription_id', update.data.id)
  }
}

function safeErrorCode(error: unknown) {
  const message = error instanceof Error ? error.message : 'unknown'
  return message.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 80)
}
