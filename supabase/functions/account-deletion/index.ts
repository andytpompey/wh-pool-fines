import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
}

type TeamImpact = { teamId: string; teamName: string }
type Preflight = { teamsDeletedWithAccount?: TeamImpact[] }

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (request.method !== 'POST') {
    return json({ message: 'Method not allowed' }, 405)
  }

  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) {
    return json({ message: 'Authentication required' }, 401)
  }

  const supabaseURL = Deno.env.get('SUPABASE_URL')
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseURL || !publishableKey || !serviceRoleKey) {
    return json({ message: 'Deletion service is unavailable' }, 503)
  }

  const userClient = createClient(supabaseURL, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const adminClient = createClient(supabaseURL, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data: userData, error: userError } = await userClient.auth.getUser()
  if (userError || !userData.user) {
    return json({ message: 'Authentication required' }, 401)
  }

  const { data: preflightData, error: preflightError } = await userClient
    .rpc('account_deletion_preflight')
  if (preflightError) {
    return json({ message: safeMessage(preflightError.message) }, 409)
  }
  const preflight = (preflightData ?? {}) as Preflight

  for (const team of preflight.teamsDeletedWithAccount ?? []) {
    const { data: objects, error: listError } = await adminClient.storage
      .from('team-logos')
      .list(team.teamId, { limit: 1000 })
    if (listError) {
      return json({ message: 'Team logo cleanup could not be completed' }, 503)
    }
    const paths = (objects ?? []).map((object) => `${team.teamId}/${object.name}`)
    if (paths.length > 0) {
      const { error: removeError } = await adminClient.storage.from('team-logos').remove(paths)
      if (removeError) {
        return json({ message: 'Team logo cleanup could not be completed' }, 503)
      }
    }
  }

  const { data, error } = await userClient.rpc('delete_current_account')
  if (error) {
    return json({ message: safeMessage(error.message) }, 409)
  }
  return json(data ?? { success: true }, 200)
})

function safeMessage(message: string): string {
  if (message.includes('Transfer captaincy')) return message
  if (message.includes('Recent authentication')) return 'Recent authentication required'
  return 'Account deletion could not be completed'
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  })
}
