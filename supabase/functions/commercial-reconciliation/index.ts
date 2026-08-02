import { createClient } from 'npm:@supabase/supabase-js@2'
import Stripe from 'npm:stripe@18'

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } })

Deno.serve(async request => {
  if (request.method !== 'POST') return json({ message: 'Method not allowed' }, 405)
  const cronSecret = Deno.env.get('COMMERCIAL_CRON_SECRET')
  if (!cronSecret || request.headers.get('x-commercial-cron-secret') !== cronSecret) return json({ message: 'Not authorised' }, 401)
  const supabaseURL = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
  if (!supabaseURL || !serviceKey || !stripeKey) return json({ message: 'Reconciliation is not configured' }, 503)

  const admin = createClient(supabaseURL, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })
  const stripe = new Stripe(stripeKey)
  const { data: subscriptions, error } = await admin.from('commercial_subscriptions')
    .select('id,provider_subscription_id,state,current_period_start,current_period_end,cancel_at_period_end')
    .eq('provider', 'stripe').not('provider_subscription_id', 'like', 'checkout:%').limit(500)
  if (error) return json({ message: 'Subscription inventory is unavailable' }, 503)

  let compared = 0; let opened = 0; let unavailable = 0
  for (const local of subscriptions ?? []) {
    compared++
    try {
      const remote = await stripe.subscriptions.retrieve(local.provider_subscription_id)
      const item = remote.items.data[0]
      const remoteState = normaliseState(remote.status)
      const differences: Record<string, unknown> = {}
      if (local.state !== remoteState) differences.state = { local: local.state, provider: remoteState }
      const remoteStart = item ? new Date(item.current_period_start * 1000).toISOString() : null
      const remoteEnd = item ? new Date(item.current_period_end * 1000).toISOString() : null
      if (!sameInstant(local.current_period_start, remoteStart)) differences.currentPeriodStart = { local: local.current_period_start, provider: remoteStart }
      if (!sameInstant(local.current_period_end, remoteEnd)) differences.currentPeriodEnd = { local: local.current_period_end, provider: remoteEnd }
      if (local.cancel_at_period_end !== remote.cancel_at_period_end) differences.cancelAtPeriodEnd = { local: local.cancel_at_period_end, provider: remote.cancel_at_period_end }
      if (Object.keys(differences).length) opened += await openCase(admin, local.id, local.provider_subscription_id, 'Stripe subscription differs from RooBin', differences)
    } catch (providerError) {
      unavailable++
      const code = providerError instanceof Error ? providerError.name : 'provider_error'
      opened += await openCase(admin, local.id, local.provider_subscription_id, 'Stripe subscription could not be reconciled', { code })
    }
  }

  const { data: internalIssues } = await admin.from('commercial_reconciliation_issues').select('*').limit(500)
  for (const issue of internalIssues ?? []) {
    opened += await openCase(admin, issue.issue_type === 'subscription_without_entitlement' || issue.issue_type === 'payment_without_financial_entry' ? issue.entity_id : null, `${issue.issue_type}:${issue.entity_id}`, `Internal reconciliation issue: ${issue.issue_type}`, { entityId: issue.entity_id, source: issue.provider })
  }
  return json({ compared, internalIssues: internalIssues?.length ?? 0, opened, providerUnavailable: unavailable, repairMode: 'operator_approval_required' })
})

async function openCase(admin: ReturnType<typeof createClient>, subscriptionId: string | null, reference: string, summary: string, details: Record<string, unknown>) {
  const existing = await admin.from('commercial_operator_cases').select('id').eq('case_type', 'reconciliation').eq('provider_reference', reference).in('state', ['open', 'investigating', 'waiting_approval']).limit(1).maybeSingle()
  if (existing.data || existing.error) return 0
  const inserted = await admin.from('commercial_operator_cases').insert({ case_type: 'reconciliation', priority: summary.includes('could not') ? 'high' : 'normal', subscription_id: subscriptionId, provider_reference: reference, summary, safe_details: details }).select('id').single()
  return inserted.error ? 0 : 1
}

function normaliseState(status: Stripe.Subscription.Status) {
  if (status === 'active' || status === 'trialing') return status
  if (status === 'past_due' || status === 'unpaid') return 'past_due'
  if (status === 'paused') return 'paused'
  if (status === 'canceled') return 'cancelled'
  return 'expired'
}

function sameInstant(left: string | null, right: string | null) {
  if (!left || !right) return left === right
  return Math.abs(new Date(left).getTime() - new Date(right).getTime()) < 1000
}
