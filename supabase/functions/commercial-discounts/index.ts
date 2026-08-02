import { createClient } from 'npm:@supabase/supabase-js@2'
import Stripe from 'npm:stripe@18'

const corsHeaders = { 'Access-Control-Allow-Origin': Deno.env.get('PUBLIC_APP_ORIGIN') ?? '', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' }
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } })

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ message: 'Method not allowed' }, 405)
  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return json({ message: 'Authentication required' }, 401)
  const supabaseURL = Deno.env.get('SUPABASE_URL'); const anonKey = Deno.env.get('SUPABASE_ANON_KEY'); const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'); const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
  if (!supabaseURL || !anonKey || !serviceKey || !stripeKey) return json({ message: 'Discount issuing is not configured' }, 503)
  const userClient = createClient(supabaseURL, anonKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false } })
  const { data: userData } = await userClient.auth.getUser()
  if (!userData.user) return json({ message: 'Authentication required' }, 401)
  const access = await userClient.rpc('get_commercial_admin_dashboard')
  if (access.error || !access.data) return json({ message: 'Commercial administrator access required' }, 403)
  let body: { discountId?: string; code?: string; maxRedemptions?: number; reason?: string }
  try { body = await request.json() } catch { return json({ message: 'Invalid JSON body' }, 400) }
  const code = (body.code || randomCode()).trim().toUpperCase()
  if (!body.discountId || !/^[A-Z0-9][A-Z0-9_-]{4,31}$/.test(code) || (body.reason?.trim().length ?? 0) < 8) return json({ message: 'Discount, valid code and reason are required' }, 400)
  const admin = createClient(supabaseURL, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data: discount } = await admin.from('commercial_discounts').select('*').eq('id', body.discountId).eq('state', 'published').maybeSingle()
  if (!discount || new Date(discount.valid_from) > new Date() || (discount.valid_until && new Date(discount.valid_until) <= new Date())) return json({ message: 'Published discount is unavailable' }, 409)
  const stripe = new Stripe(stripeKey)
  let couponId = discount.provider_refs?.stripeCoupon
  if (!couponId) {
    const coupon = await stripe.coupons.create({
      name: discount.name, duration: 'once',
      ...(discount.discount_type === 'fixed' ? { amount_off: discount.amount_minor, currency: discount.currency.toLowerCase() } : { percent_off: Number(discount.percentage) }),
      metadata: { roobin_discount_id: discount.id },
    }, { idempotencyKey: `roobin-discount-${discount.id}` })
    couponId = coupon.id
    await admin.from('commercial_discounts').update({ provider_refs: { ...discount.provider_refs, stripeCoupon: couponId } }).eq('id', discount.id)
  }
  let promotion: Stripe.PromotionCode
  try {
    promotion = await stripe.promotionCodes.create({ promotion: { type: 'coupon', coupon: couponId }, code, active: true, max_redemptions: Math.max(1, Math.min(body.maxRedemptions ?? 1, discount.total_redemption_limit ?? 1)), expires_at: discount.valid_until ? Math.floor(new Date(discount.valid_until).getTime() / 1000) : undefined, metadata: { roobin_discount_id: discount.id } })
  } catch { return json({ message: 'That code is unavailable or the provider rejected it' }, 409) }
  const digest = await sha256(code)
  const insert = await admin.from('commercial_discount_codes').insert({ discount_id: discount.id, code_digest: digest, code_hint: `${code.slice(0, 2)}…${code.slice(-2)}`, max_redemptions: promotion.max_redemptions ?? 1, provider_reference: promotion.id, created_by: userData.user.id }).select('id').single()
  if (insert.error) { await stripe.promotionCodes.update(promotion.id, { active: false }); return json({ message: 'Code could not be recorded safely' }, 503) }
  await admin.from('commercial_audit_log').insert({ actor_user_id: userData.user.id, action: 'discount_code.issued', entity_type: 'commercial_discount_code', entity_id: insert.data.id, after_data: { discountId: discount.id, codeHint: `${code.slice(0, 2)}…${code.slice(-2)}`, providerReference: promotion.id }, reason: body.reason?.trim() })
  return json({ code, codeHint: `${code.slice(0, 2)}…${code.slice(-2)}` })
})

function randomCode() { const bytes = crypto.getRandomValues(new Uint8Array(6)); return `ROOBIN-${Array.from(bytes).map(value => (value % 36).toString(36)).join('').toUpperCase()}` }
async function sha256(value: string) { const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)); return Array.from(new Uint8Array(digest)).map(byte => byte.toString(16).padStart(2, '0')).join('') }
