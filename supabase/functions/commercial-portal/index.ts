import { createClient } from 'npm:@supabase/supabase-js@2'
import Stripe from 'npm:stripe@18'

const origin = Deno.env.get('PUBLIC_APP_ORIGIN') ?? ''
const headers = {
  'Access-Control-Allow-Origin': origin,
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers })
  if (request.method !== 'POST') return json({ message: 'Method not allowed' }, 405)
  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return json({ message: 'Authentication required' }, 401)
  const supabaseURL = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
  if (!supabaseURL || !anonKey || !serviceKey || !stripeKey || !origin) return json({ message: 'Billing portal is not configured' }, 503)

  let body: { teamId?: string }
  try { body = await request.json() } catch { return json({ message: 'Invalid JSON body' }, 400) }
  if (!body.teamId) return json({ message: 'Team is required' }, 400)
  const userClient = createClient(supabaseURL, anonKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } })
  const admin = createClient(supabaseURL, serviceKey, { auth: { persistSession: false } })
  const { data: userData } = await userClient.auth.getUser()
  if (!userData.user) return json({ message: 'Authentication required' }, 401)
  if (!await consumeLimit(admin, `${userData.user.id}:${body.teamId}`, 'commercial_portal', 8)) return json({ message: 'Too many billing portal requests. Wait a few minutes and try again.' }, 429)
  const { data: customer } = await admin.from('billing_customers').select('id, provider_customer_refs')
    .eq('owner_user_id', userData.user.id).eq('team_id', body.teamId).maybeSingle()
  if (!customer?.provider_customer_refs?.stripe) return json({ message: 'No web billing account exists for this team' }, 404)
  const session = await new Stripe(stripeKey).billingPortal.sessions.create({
    customer: customer.provider_customer_refs.stripe,
    return_url: `${origin}/teams/${body.teamId}`,
  })
  return json({ portalUrl: session.url }, 200)
})

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), { status, headers: { ...headers, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } })
}

async function consumeLimit(admin: ReturnType<typeof createClient>, source: string, kind: string, maximum: number) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(source))
  const requestHash = Array.from(new Uint8Array(digest)).map(byte => byte.toString(16).padStart(2, '0')).join('')
  const windowStartedAt = new Date(Math.floor(Date.now() / 600_000) * 600_000).toISOString()
  const current = await admin.from('public_request_limits').select('request_count').eq('request_hash', requestHash).eq('request_kind', kind).eq('window_started_at', windowStartedAt).maybeSingle()
  if (current.error || (current.data?.request_count ?? 0) >= maximum) return false
  const updated = await admin.from('public_request_limits').upsert({ request_hash: requestHash, request_kind: kind, window_started_at: windowStartedAt, request_count: (current.data?.request_count ?? 0) + 1 }, { onConflict: 'request_hash,request_kind,window_started_at' })
  return !updated.error
}
