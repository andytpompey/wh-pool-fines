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
      const session = event.data.object as Stripe.Checkout.Session
      await fulfilCheckout(admin, session)
      await recordCheckoutFinancialEntry(admin, stripe, session)
    } else if (event.type === 'invoice.paid' || event.type === 'invoice.payment_failed' || event.type.startsWith('customer.subscription.')) {
      await reconcileSubscription(admin, stripe, event)
    } else if (event.type === 'charge.refunded') {
      await recordRefund(admin, event.data.object as Stripe.Charge)
    } else if (event.type === 'charge.dispute.created' || event.type === 'charge.dispute.closed') {
      await recordDispute(admin, event.type, event.data.object as Stripe.Dispute)
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
  const required = ['roobin_team_id', 'roobin_playing_cycle_id', 'roobin_coverage_start', 'roobin_coverage_end', 'roobin_offering_id', 'roobin_price_version_id', 'roobin_billing_customer_id']
  if (required.some(key => !meta[key])) throw new Error('checkout_metadata_invalid')
  const { data: offering } = await admin.from('commercial_offerings').select('entitlement_definition_id').eq('id', meta.roobin_offering_id).single()
  if (!offering) throw new Error('offering_missing')
  const start = new Date(`${meta.roobin_coverage_start}T00:00:00.000Z`)
  const end = new Date(`${meta.roobin_coverage_end}T23:59:59.999Z`)
  if (!Number.isFinite(start.valueOf()) || !Number.isFinite(end.valueOf()) || end <= start) throw new Error('coverage_invalid')
  const providerSubscriptionId = typeof session.subscription === 'string' ? session.subscription : null
  const subscriptionResult = await admin.from('commercial_subscriptions').upsert({
    billing_customer_id: meta.roobin_billing_customer_id,
    offering_id: meta.roobin_offering_id,
    price_version_id: meta.roobin_price_version_id,
    team_id: meta.roobin_team_id,
    playing_cycle_id: meta.roobin_playing_cycle_id,
    provider: 'stripe',
    provider_subscription_id: providerSubscriptionId ?? `checkout:${session.id}`,
    state: 'active', current_period_start: start.toISOString(), current_period_end: end.toISOString(),
    metadata: { checkout_session_id: session.id, payment_intent_id: session.payment_intent },
  }, { onConflict: 'provider,provider_subscription_id' }).select('id').single()
  if (subscriptionResult.error) throw subscriptionResult.error
  const entitlementResult = await admin.from('team_season_entitlements').upsert({
    team_id: meta.roobin_team_id, playing_cycle_id: meta.roobin_playing_cycle_id,
    subscription_id: subscriptionResult.data.id, entitlement_definition_id: offering.entitlement_definition_id,
    state: 'active', valid_from: start.toISOString(), valid_until: end.toISOString(),
    source: 'purchase', source_reference: `stripe:${session.id}`,
  }, { onConflict: 'team_id,playing_cycle_id,entitlement_definition_id,subscription_id' })
  if (entitlementResult.error) throw entitlementResult.error
}

async function findSubscriptionByPaymentIntent(admin: ReturnType<typeof createClient>, paymentIntentId: string | null) {
  if (!paymentIntentId) return null
  const { data, error } = await admin.from('commercial_subscriptions').select('id')
    .contains('metadata', { payment_intent_id: paymentIntentId }).maybeSingle()
  if (error) throw error
  return data
}

async function recordCheckoutFinancialEntry(admin: ReturnType<typeof createClient>, stripe: Stripe, session: Stripe.Checkout.Session) {
  if (!session.payment_intent || session.payment_status !== 'paid') return
  const paymentIntentId = typeof session.payment_intent === 'string' ? session.payment_intent : session.payment_intent.id
  const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId, { expand: ['latest_charge.balance_transaction'] })
  const charge = typeof paymentIntent.latest_charge === 'object' ? paymentIntent.latest_charge as Stripe.Charge : null
  const balance = charge && typeof charge.balance_transaction === 'object' ? charge.balance_transaction as Stripe.BalanceTransaction : null
  const subscription = await findSubscriptionByPaymentIntent(admin, paymentIntentId)
  const gross = session.amount_total ?? paymentIntent.amount_received
  const discount = session.total_details?.amount_discount ?? 0
  const tax = session.total_details?.amount_tax ?? 0
  const fee = balance?.fee ?? 0
  const result = await admin.from('commercial_financial_entries').upsert({
    subscription_id: subscription?.id ?? null, provider: 'stripe', provider_reference: paymentIntentId,
    entry_type: 'charge', currency: (session.currency ?? paymentIntent.currency).toUpperCase(),
    gross_amount_minor: gross, discount_amount_minor: discount, tax_amount_minor: tax,
    processor_fee_minor: fee, net_amount_minor: balance?.net ?? (gross - fee),
    receipt_url: charge?.receipt_url ?? null,
    occurred_at: new Date((charge?.created ?? session.created) * 1000).toISOString(),
  }, { onConflict: 'provider,provider_reference,entry_type' })
  if (result.error) throw result.error
  if (subscription && discount > 0) {
    const detailed = await stripe.checkout.sessions.retrieve(session.id, { expand: ['total_details.breakdown.discounts.discount'] })
    const breakdown = (detailed.total_details?.breakdown?.discounts ?? []) as unknown as Array<{ discount?: unknown }>
    const promotionReference = breakdown.map(item => promotionCodeId(item.discount)).find(Boolean)
    if (promotionReference) {
      const redemption = await admin.rpc('record_discount_redemption_from_provider', {
        provider_promotion_reference: promotionReference,
        target_subscription_id: subscription.id,
        target_billing_customer_id: session.metadata?.roobin_billing_customer_id,
        undiscounted_minor: gross + discount,
        discounted_minor: gross,
        target_currency: (session.currency ?? paymentIntent.currency).toUpperCase(),
        payment_reference: paymentIntentId,
      })
      if (redemption.error) throw redemption.error
    }
  }
}

function promotionCodeId(value: unknown): string | null {
  if (!value || typeof value !== 'object') return null
  const discount = value as Record<string, unknown>
  const candidates = [discount.promotion_code, (discount.source as Record<string, unknown> | undefined)?.promotion_code]
  for (const candidate of candidates) {
    if (typeof candidate === 'string') return candidate
    if (candidate && typeof candidate === 'object' && typeof (candidate as Record<string, unknown>).id === 'string') return (candidate as Record<string, unknown>).id as string
  }
  return null
}

async function recordRefund(admin: ReturnType<typeof createClient>, charge: Stripe.Charge) {
  const paymentIntentId = typeof charge.payment_intent === 'string' ? charge.payment_intent : charge.payment_intent?.id ?? null
  const subscription = await findSubscriptionByPaymentIntent(admin, paymentIntentId)
  for (const refund of charge.refunds?.data ?? []) {
    const result = await admin.from('commercial_financial_entries').upsert({
      subscription_id: subscription?.id ?? null, provider: 'stripe', provider_reference: refund.id,
      entry_type: 'refund', currency: refund.currency.toUpperCase(), gross_amount_minor: -refund.amount,
      discount_amount_minor: 0, tax_amount_minor: 0, processor_fee_minor: 0, net_amount_minor: -refund.amount,
      occurred_at: new Date(refund.created * 1000).toISOString(),
    }, { onConflict: 'provider,provider_reference,entry_type' })
    if (result.error) throw result.error
    await openOperatorCase(admin, {
      case_type: 'refund', state: charge.amount_refunded >= charge.amount ? 'resolved' : 'open',
      priority: 'normal', subscription_id: subscription?.id ?? null, provider_reference: refund.id,
      summary: charge.amount_refunded >= charge.amount ? 'Full Stripe refund reconciled' : 'Partial Stripe refund requires access-policy review',
      safe_details: { refundAmountMinor: refund.amount, cumulativeRefundMinor: charge.amount_refunded, originalChargeMinor: charge.amount, currency: refund.currency.toUpperCase() },
      resolved_at: charge.amount_refunded >= charge.amount ? new Date().toISOString() : null,
    })
  }
  if (subscription && charge.amount_refunded >= charge.amount) {
    await admin.from('commercial_subscriptions').update({ state: 'cancelled', cancelled_at: new Date().toISOString() }).eq('id', subscription.id)
    await admin.from('team_season_entitlements').update({ state: 'refunded', updated_at: new Date().toISOString() }).eq('subscription_id', subscription.id)
    await enqueueLifecycleNotification(admin, subscription.id, 'refunded', `refund:${charge.id}`)
  }
}

async function recordDispute(admin: ReturnType<typeof createClient>, eventType: string, dispute: Stripe.Dispute) {
  const chargeId = typeof dispute.charge === 'string' ? dispute.charge : dispute.charge?.id
  const paymentIntentId = typeof dispute.payment_intent === 'string' ? dispute.payment_intent : dispute.payment_intent?.id ?? null
  const subscription = await findSubscriptionByPaymentIntent(admin, paymentIntentId)
  const resolvedInCustomerFavour = eventType === 'charge.dispute.closed' && dispute.status === 'won'
  const entryType = resolvedInCustomerFavour ? 'dispute_reversal' : 'dispute'
  const signedAmount = resolvedInCustomerFavour ? dispute.amount : -dispute.amount
  const result = await admin.from('commercial_financial_entries').upsert({
    subscription_id: subscription?.id ?? null, provider: 'stripe', provider_reference: `${dispute.id}:${dispute.status}`,
    entry_type: entryType, currency: dispute.currency.toUpperCase(), gross_amount_minor: signedAmount,
    discount_amount_minor: 0, tax_amount_minor: 0, processor_fee_minor: 0, net_amount_minor: signedAmount,
    occurred_at: new Date(dispute.created * 1000).toISOString(),
  }, { onConflict: 'provider,provider_reference,entry_type' })
  if (result.error) throw result.error
  if (subscription) {
    await admin.from('commercial_subscriptions').update({ state: resolvedInCustomerFavour ? 'active' : 'past_due' }).eq('id', subscription.id)
    await admin.from('team_season_entitlements').update({ state: resolvedInCustomerFavour ? 'active' : 'grace', updated_at: new Date().toISOString() }).eq('subscription_id', subscription.id)
    await admin.from('commercial_audit_log').insert({
      action: resolvedInCustomerFavour ? 'dispute.resolved' : 'dispute.opened', entity_type: 'commercial_subscription',
      entity_id: subscription.id, reason: `Stripe dispute ${dispute.id} (${chargeId ?? 'charge unavailable'})`,
      after_data: { dispute_id: dispute.id, status: dispute.status },
    })
    await enqueueLifecycleNotification(admin, subscription.id, resolvedInCustomerFavour ? 'payment_recovered' : 'dispute', `dispute:${dispute.id}:${dispute.status}`)
  }
  await openOperatorCase(admin, {
    case_type: 'dispute', state: eventType === 'charge.dispute.closed' ? 'resolved' : 'open', priority: 'high',
    subscription_id: subscription?.id ?? null, provider_reference: dispute.id,
    summary: eventType === 'charge.dispute.closed' ? `Stripe dispute closed: ${dispute.status}` : 'Stripe dispute opened',
    safe_details: { status: dispute.status, amountMinor: dispute.amount, currency: dispute.currency.toUpperCase(), chargeReference: chargeId },
    resolved_at: eventType === 'charge.dispute.closed' ? new Date().toISOString() : null,
  })
}

async function openOperatorCase(admin: ReturnType<typeof createClient>, values: Record<string, unknown>) {
  const reference = values.provider_reference as string
  const type = values.case_type as string
  const existing = await admin.from('commercial_operator_cases').select('id').eq('case_type', type).eq('provider_reference', reference).limit(1).maybeSingle()
  if (existing.error) throw existing.error
  if (!existing.data) {
    const result = await admin.from('commercial_operator_cases').insert(values)
    if (result.error) throw result.error
  } else if (values.state === 'resolved') {
    const result = await admin.from('commercial_operator_cases').update({ state: 'resolved', summary: values.summary, safe_details: values.safe_details, resolved_at: values.resolved_at, updated_at: new Date().toISOString() }).eq('id', existing.data.id)
    if (result.error) throw result.error
  }
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
  const local = await admin.from('commercial_subscriptions').select('id,offering_id,commercial_offerings(lifecycle_policy)').eq('provider','stripe').eq('provider_subscription_id',subscriptionId).maybeSingle()
  if (local.error) throw local.error
  const lifecycle = (local.data?.commercial_offerings as unknown as { lifecycle_policy?: { graceDays?: number } } | null)?.lifecycle_policy ?? { graceDays: 7 }
  const periodEnd = new Date(item.current_period_end * 1000)
  const graceBase = Math.max(Date.now(), periodEnd.getTime())
  const graceUntil = state === 'past_due' ? new Date(graceBase + Math.max(0,Math.min(30,lifecycle.graceDays ?? 7))*86_400_000).toISOString() : null
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
      valid_until: periodEnd.toISOString(), grace_until: graceUntil, updated_at: new Date().toISOString(),
    }).eq('subscription_id', update.data.id)
    const notificationType = event.type === 'invoice.payment_failed' ? 'payment_failed'
      : event.type === 'invoice.paid' ? 'payment_recovered'
        : event.type === 'customer.subscription.deleted' ? 'cancelled' : null
    if (notificationType) await enqueueLifecycleNotification(admin, update.data.id, notificationType, `stripe:${event.id}`)
  }
}

async function enqueueLifecycleNotification(admin: ReturnType<typeof createClient>, subscriptionId: string, notificationType: string, notificationKey: string) {
  const { data: subscription, error } = await admin.from('commercial_subscriptions').select('id,billing_customer_id,billing_customers(billing_email)').eq('id', subscriptionId).maybeSingle()
  if (error || !subscription) return
  const customer = subscription.billing_customers as unknown as { billing_email?: string | null }
  if (!customer?.billing_email) return
  await admin.from('commercial_notification_deliveries').upsert({
    notification_key: notificationKey, notification_type: notificationType,
    billing_customer_id: subscription.billing_customer_id, subscription_id: subscription.id,
    recipient_digest: await sha256(customer.billing_email.toLowerCase()), status: 'queued', scheduled_for: new Date().toISOString(), attempt_count: 0,
  }, { onConflict: 'notification_key', ignoreDuplicates: true })
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))
  return Array.from(new Uint8Array(digest)).map(byte => byte.toString(16).padStart(2, '0')).join('')
}

function safeErrorCode(error: unknown) {
  const message = error instanceof Error ? error.message : 'unknown'
  return message.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 80)
}
