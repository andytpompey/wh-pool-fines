import { createClient } from 'npm:@supabase/supabase-js@2'
import { Environment, SignedDataVerifier } from 'npm:@apple/app-store-server-library@2'
import { Buffer } from 'node:buffer'

const headers = {
  'Access-Control-Allow-Origin': Deno.env.get('PUBLIC_APP_ORIGIN') ?? '',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers })
  if (request.method !== 'POST') return json({ message: 'Method not allowed' }, 405)
  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return json({ message: 'Authentication required' }, 401)
  let body: { signedTransaction?: string }
  try { body = await request.json() } catch { return json({ message: 'Invalid JSON body' }, 400) }
  if (!body.signedTransaction || body.signedTransaction.length > 100_000) return json({ message: 'Signed transaction is required' }, 400)

  const supabaseURL = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const rootsJSON = Deno.env.get('APPLE_ROOT_CERTIFICATES_BASE64_JSON')
  const configuredEnvironment = Deno.env.get('APP_STORE_ENVIRONMENT') ?? 'SANDBOX'
  const bundleId = Deno.env.get('APP_STORE_BUNDLE_ID') ?? 'com.roobin.app'
  const appAppleId = Deno.env.get('APP_STORE_APP_APPLE_ID')
  if (!supabaseURL || !anonKey || !serviceKey || !rootsJSON) return json({ message: 'App Store verification is not configured' }, 503)

  const userClient = createClient(supabaseURL, anonKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } })
  const admin = createClient(supabaseURL, serviceKey, { auth: { persistSession: false } })
  const { data: userData } = await userClient.auth.getUser()
  if (!userData.user) return json({ message: 'Authentication required' }, 401)
  let roots: Buffer[]
  try { roots = (JSON.parse(rootsJSON) as string[]).map(value => Buffer.from(value, 'base64')) }
  catch { return json({ message: 'App Store verification is not configured' }, 503) }
  const environment = configuredEnvironment === 'PRODUCTION' ? Environment.PRODUCTION : Environment.SANDBOX
  const verifier = new SignedDataVerifier(roots, true, environment, bundleId, environment === Environment.PRODUCTION ? Number(appAppleId) : undefined)
  let transaction
  try { transaction = await verifier.verifyAndDecodeTransaction(body.signedTransaction) }
  catch { return json({ message: 'Apple transaction verification failed' }, 400) }
  if (!transaction.transactionId || !transaction.originalTransactionId || !transaction.productId || !transaction.appAccountToken || !transaction.purchaseDate) {
    return json({ message: 'Apple transaction is incomplete' }, 400)
  }

  const { data: context } = await admin.from('app_store_purchase_contexts').select('*, team_playing_cycles(starts_on,ends_on), commercial_offerings(entitlement_definition_id)')
    .eq('id', transaction.appAccountToken).eq('owner_user_id', userData.user.id).maybeSingle()
  if (!context) return json({ message: 'Purchase context is unavailable' }, 409)
  if (context.product_id !== transaction.productId) return json({ message: 'Apple product does not match the approved offer' }, 409)
  if (context.state === 'pending' && new Date(context.expires_at) < new Date()) return json({ message: 'Purchase context expired; start purchase again' }, 409)

  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(body.signedTransaction))
  const digestHex = [...new Uint8Array(digest)].map(value => value.toString(16).padStart(2, '0')).join('')
  const environmentName = transaction.environment ?? (environment === Environment.PRODUCTION ? 'Production' : 'Sandbox')
  const transactionResult = await admin.from('app_store_transactions').upsert({
    purchase_context_id: context.id, transaction_id: transaction.transactionId,
    original_transaction_id: transaction.originalTransactionId, product_id: transaction.productId,
    app_account_token: transaction.appAccountToken, environment: environmentName,
    purchase_date: new Date(transaction.purchaseDate).toISOString(),
    expires_date: transaction.expiresDate ? new Date(transaction.expiresDate).toISOString() : null,
    revocation_date: transaction.revocationDate ? new Date(transaction.revocationDate).toISOString() : null,
    signed_transaction_digest: digestHex, decoded_payload: transaction,
  }, { onConflict: 'transaction_id' }).select('id').single()
  if (transactionResult.error) return json({ message: 'Verified Apple transaction could not be recorded' }, 503)

  const cycle = context.team_playing_cycles
  const start = new Date(`${cycle.starts_on}T00:00:00.000Z`)
  const end = new Date(`${cycle.ends_on}T23:59:59.999Z`)
  const revoked = Boolean(transaction.revocationDate)
  let { data: customer } = await admin.from('billing_customers').select('id,provider_customer_refs').eq('owner_user_id',userData.user.id).eq('team_id',context.team_id).maybeSingle()
  if (!customer) {
    const result = await admin.from('billing_customers').insert({ owner_user_id:userData.user.id,customer_type:'team',team_id:context.team_id,provider_customer_refs:{app_store:userData.user.id},billing_email:userData.user.email }).select('id,provider_customer_refs').single()
    if (result.error) return json({ message: 'Apple billing customer could not be recorded' }, 503)
    customer = result.data
  }
  const subscriptionResult = await admin.from('commercial_subscriptions').upsert({
    billing_customer_id:customer.id,offering_id:context.offering_id,price_version_id:context.price_version_id,
    team_id:context.team_id,playing_cycle_id:context.playing_cycle_id,provider:'app_store',provider_subscription_id:transaction.originalTransactionId,
    state:revoked?'cancelled':'active',current_period_start:start.toISOString(),current_period_end:end.toISOString(),
    cancelled_at:revoked?new Date(transaction.revocationDate).toISOString():null,metadata:{transaction_id:transaction.transactionId,environment:environmentName},
  }, { onConflict:'provider,provider_subscription_id' }).select('id').single()
  if (subscriptionResult.error) return json({ message: 'Apple subscription could not be reconciled' }, 503)
  const entitlementResult = await admin.from('team_season_entitlements').upsert({
    team_id:context.team_id,playing_cycle_id:context.playing_cycle_id,subscription_id:subscriptionResult.data.id,
    entitlement_definition_id:context.commercial_offerings.entitlement_definition_id,state:revoked?'refunded':'active',
    valid_from:start.toISOString(),valid_until:end.toISOString(),source:'purchase',source_reference:`app_store:${transaction.transactionId}`,
  }, { onConflict:'team_id,playing_cycle_id,entitlement_definition_id,subscription_id' })
  if (entitlementResult.error) return json({ message: 'Apple entitlement could not be reconciled' }, 503)
  await admin.from('app_store_purchase_contexts').update({state:'completed',completed_at:new Date().toISOString()}).eq('id',context.id)
  return json({ verified:true,state:revoked?'refunded':'active',playingCycleId:context.playing_cycle_id },200)
})

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), { status, headers: { ...headers, 'Content-Type':'application/json','Cache-Control':'no-store' } })
}
