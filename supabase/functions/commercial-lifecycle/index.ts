import { createClient } from 'npm:@supabase/supabase-js@2'

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } })

Deno.serve(async request => {
  if (request.method !== 'POST') return json({ message: 'Method not allowed' }, 405)
  const expectedSecret = Deno.env.get('COMMERCIAL_CRON_SECRET')
  if (!expectedSecret || request.headers.get('x-commercial-cron-secret') !== expectedSecret) return json({ message: 'Not authorised' }, 401)
  const supabaseURL = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseURL || !serviceRoleKey) return json({ message: 'Commercial lifecycle is not configured' }, 503)
  const body = await request.json().catch(() => ({})) as { mode?: string; policyVersion?: string }
  const previewOnly = body.mode !== 'apply'
  const policyVersion = body.policyVersion?.trim() || 'v1.0'
  if (!/^v\d+\.\d+$/.test(policyVersion)) return json({ message: 'Invalid policy version' }, 400)
  const admin = createClient(supabaseURL, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data, error } = await admin.rpc('run_commercial_retention', { target_policy_version: policyVersion, preview_only: previewOnly })
  if (error) return json({ message: 'Commercial lifecycle run failed', code: error.code }, 503)
  return json({ mode: previewOnly ? 'preview' : 'apply', policyVersion, result: data })
})
