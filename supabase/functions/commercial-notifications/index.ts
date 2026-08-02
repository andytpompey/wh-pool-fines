import { createClient } from 'npm:@supabase/supabase-js@2'

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } })
const escapeHtml = (value: string) => value.replace(/[&<>'"]/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[character]!)

Deno.serve(async request => {
  if (request.method !== 'POST') return json({ message: 'Method not allowed' }, 405)
  const expectedSecret = Deno.env.get('COMMERCIAL_CRON_SECRET')
  if (!expectedSecret || request.headers.get('x-commercial-cron-secret') !== expectedSecret) return json({ message: 'Not authorised' }, 401)
  const supabaseURL = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const resendKey = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('TEAM_EMAIL_FROM')
  const publicOrigin = Deno.env.get('PUBLIC_APP_ORIGIN')
  if (!supabaseURL || !serviceRoleKey || !resendKey || !from || !publicOrigin) return json({ message: 'Notifications are not configured' }, 503)
  const admin = createClient(supabaseURL, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data: due, error } = await admin.from('commercial_notifications_due').select('*').limit(100)
  if (error) return json({ message: 'Notification queue is unavailable' }, 503)
  let delivered = 0; let failed = 0
  for (const item of due ?? []) {
    const recipientDigest = await sha256(item.recipient.toLowerCase())
    const claimed = await admin.from('commercial_notification_deliveries').insert({
      notification_key: item.notification_key, notification_type: item.notification_type,
      billing_customer_id: item.billing_customer_id, subscription_id: item.subscription_id,
      entitlement_id: item.entitlement_id, recipient_digest: recipientDigest, status: 'queued', scheduled_for: new Date().toISOString(), attempt_count: 1,
    }).select('id').maybeSingle()
    if (claimed.error?.code === '23505' || !claimed.data) continue
    try {
      const renewalCopy = item.renewal_behaviour === 'automatic'
        ? `Your approved subscription is expected to renew for ${money(item.amount_minor, item.currency)}. You can review or cancel it from RooBin billing.`
        : `This playing cycle does not renew automatically. A captain can purchase the next cycle from Team Subscription.`
      const response = await fetch('https://api.resend.com/emails', { method: 'POST', headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' }, body: JSON.stringify({
        from, to: [item.recipient], subject: `${item.team_name} RooBin access ends in ${item.days_before} days`,
        text: `${item.team_name} access for ${item.cycle_name} ends on ${new Date(item.valid_until).toLocaleDateString('en-GB')}. ${renewalCopy} Open billing: ${publicOrigin}/app`,
        html: `<p>RooBin access for <strong>${escapeHtml(item.team_name)}</strong> / ${escapeHtml(item.cycle_name)} ends on ${escapeHtml(new Date(item.valid_until).toLocaleDateString('en-GB'))}.</p><p>${escapeHtml(renewalCopy)}</p><p><a href="${escapeHtml(publicOrigin)}/app">Open RooBin billing</a></p>`,
      }) })
      if (!response.ok) throw new Error(`provider_${response.status}`)
      const providerResult = await response.json().catch(() => ({}))
      await admin.from('commercial_notification_deliveries').update({ status: 'delivered', provider_message_id: providerResult.id ?? null, delivered_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('id', claimed.data.id)
      delivered++
    } catch (deliveryError) {
      const code = deliveryError instanceof Error ? deliveryError.message.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 80) : 'unknown'
      await admin.from('commercial_notification_deliveries').update({ status: 'failed', last_error_code: code, updated_at: new Date().toISOString() }).eq('id', claimed.data.id)
      failed++
    }
  }
  return json({ processed: (due ?? []).length, delivered, failed })
})

function money(amountMinor: number | null, currency: string | null) {
  if (amountMinor == null) return 'the agreed price'
  return new Intl.NumberFormat('en-GB', { style: 'currency', currency: currency ?? 'GBP' }).format(amountMinor / 100)
}
async function sha256(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))
  return Array.from(new Uint8Array(digest)).map(byte => byte.toString(16).padStart(2, '0')).join('')
}
