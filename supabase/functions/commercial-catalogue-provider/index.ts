import { createClient } from 'npm:@supabase/supabase-js@2'
import Stripe from 'npm:stripe@18'

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } })

Deno.serve(async request => {
  if (request.method !== 'POST') return json({ message: 'Method not allowed' }, 405)
  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return json({ message: 'Authentication required' }, 401)
  const supabaseURL = Deno.env.get('SUPABASE_URL'); const anonKey = Deno.env.get('SUPABASE_ANON_KEY'); const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'); const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
  if (!supabaseURL || !anonKey || !serviceKey || !stripeKey) return json({ message: 'Catalogue provider binding is not configured' }, 503)
  let body: { priceId?: string; reason?: string }
  try { body = await request.json() } catch { return json({ message: 'Invalid JSON body' }, 400) }
  if (!body.priceId || (body.reason?.trim().length ?? 0) < 8) return json({ message: 'Price and approval reason are required' }, 400)
  const user = createClient(supabaseURL, anonKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } })
  const dashboard = await user.rpc('get_commercial_admin_dashboard')
  if (dashboard.error || !dashboard.data) return json({ message: 'Commercial administrator access required' }, 403)
  const admin = createClient(supabaseURL, serviceKey, { auth: { persistSession: false } })
  const priceResult = await admin.from('commercial_price_versions').select('id,amount_minor,currency,tax_behaviour,state,provider_price_refs,commercial_offerings(id,code,version,billing_interval,renewal_behaviour,commercial_products(name,description))').eq('id', body.priceId).single()
  if (priceResult.error || !priceResult.data || priceResult.data.state !== 'published') return json({ message: 'Published price version not found' }, 404)
  const price = priceResult.data
  if (price.provider_price_refs?.stripe) return json({ priceReference: price.provider_price_refs.stripe, duplicate: true })
  const offering = price.commercial_offerings as unknown as { id: string; code: string; version: number; billing_interval: string; renewal_behaviour: string; commercial_products: { name: string; description?: string | null } }
  const stripe = new Stripe(stripeKey)
  const product = await stripe.products.create({ name: offering.commercial_products.name, description: offering.commercial_products.description ?? undefined, metadata: { roobin_offering_id: offering.id, roobin_offering_code: offering.code, roobin_offering_version: String(offering.version) } }, { idempotencyKey: `roobin-product-${offering.id}` })
  const recurring = offering.renewal_behaviour === 'automatic' && (offering.billing_interval === 'month' || offering.billing_interval === 'year') ? { interval: offering.billing_interval as 'month' | 'year' } : undefined
  const stripePrice = await stripe.prices.create({ product: product.id, unit_amount: price.amount_minor, currency: price.currency.toLowerCase(), tax_behavior: price.tax_behaviour === 'provider_calculated' ? 'unspecified' : price.tax_behaviour, recurring, metadata: { roobin_price_version_id: price.id } }, { idempotencyKey: `roobin-price-${price.id}` })
  const binding = await user.rpc('bind_commercial_price_provider', { target_price_id: price.id, provider_name: 'stripe', provider_reference: stripePrice.id, reason: body.reason.trim() })
  if (binding.error) { await stripe.prices.update(stripePrice.id, { active: false }); return json({ message: 'Stripe price was disabled because RooBin binding failed' }, 503) }
  return json({ priceReference: stripePrice.id, productReference: product.id })
})
