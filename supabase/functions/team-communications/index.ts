import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('APP_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

async function deliverInvite(
  prepared: Record<string, string>,
  admin: ReturnType<typeof createClient>,
) {
  const apiKey = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('TEAM_EMAIL_FROM')
  const appUrl = Deno.env.get('APP_PUBLIC_URL')
  if (!apiKey || !from || !appUrl) {
    return { delivered: false, mode: 'disabled' }
  }

  const inviteUrl = new URL('/invite', appUrl)
  inviteUrl.searchParams.set('token', prepared.token)
  const { data: authLink, error: authLinkError } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email: prepared.email,
    options: { redirectTo: inviteUrl.toString() },
  })
  if (authLinkError || !authLink?.properties?.action_link) {
    throw new Error('Secure invitation link could not be generated')
  }
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [prepared.email],
      subject: `Join ${prepared.teamName} on Roo Bin`,
      text: `${prepared.playerName}, you have been invited to ${prepared.teamName}. Open this secure link to verify your email, sign in and accept the invitation: ${authLink.properties.action_link}`,
    }),
  })
  if (!response.ok) throw new Error('Invite delivery provider rejected the request')
  return { delivered: true, mode: 'email' }
}

async function deliverUnlockReset(prepared: {
  teamName: string
  unlockCode: string
  recipients: Array<{ email: string; playerName: string }>
}) {
  const apiKey = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('TEAM_EMAIL_FROM')
  if (!apiKey || !from) throw new Error('Unlock-code notification delivery is not configured')

  const response = await fetch('https://api.resend.com/emails/batch', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(prepared.recipients.map(recipient => {
      const safeName = escapeHtml(recipient.playerName || 'Captain')
      const safeTeam = escapeHtml(prepared.teamName)
      const safeCode = escapeHtml(prepared.unlockCode)
      return {
        from,
        to: [recipient.email],
        subject: `${prepared.teamName} unlock code reset`,
        text: `${recipient.playerName || 'Captain'}, the new ${prepared.teamName} unlock code is ${prepared.unlockCode}. Keep it private.`,
        html: `<!doctype html><html lang="en"><body style="margin:0;background:#0b0b0b;color:#f5f5f5;font-family:Arial,sans-serif"><table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#111;border:1px solid #292929;border-radius:18px"><tr><td style="padding:32px"><div style="color:#f4b400;font-size:13px;font-weight:bold;text-transform:uppercase;letter-spacing:1px">RooBin security</div><h1 style="color:#fff;font-size:28px">Team unlock code reset</h1><p style="color:#d6d6d6;font-size:16px;line-height:24px">Hi ${safeName}, the unlock code for ${safeTeam} has been securely reset.</p><div style="margin:24px 0;padding:22px;text-align:center;background:#1d1d1d;border:1px solid #333;border-radius:14px"><div style="color:#aaa;font-size:12px;text-transform:uppercase;letter-spacing:1px">New unlock code</div><div style="margin-top:10px;color:#f4b400;font-size:38px;font-weight:bold;letter-spacing:5px">${safeCode}</div></div><p style="color:#d6d6d6;font-size:15px;line-height:23px">Keep this code private and share it only with eligible team leaders.</p><p style="color:#888;font-size:13px">If you did not request this reset, review your team access immediately.</p></td></tr></table></td></tr></table></body></html>`,
      }
    })),
  })
  if (!response.ok) throw new Error('Unlock-code notification provider rejected the request')
  return { delivered: true }
}

function escapeHtml(value: string) {
  return value.replace(/[&<>'"]/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;',
  })[character]!)
}

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json(405, { error: 'Method not allowed' })

  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return json(401, { error: 'Authentication required' })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authorization } } },
  )
  const { data: userData, error: userError } = await supabase.auth.getUser()
  if (userError || !userData.user) return json(401, { error: 'Invalid session' })
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  )

  try {
    const body = await request.json()
    let prepared
    if (body?.action === 'invite') {
      const result = await admin.rpc('prepare_team_invite_as_service', {
        actor_user_id: userData.user.id,
        target_team_id: body.teamId,
        invite_email: body.email,
        invite_display_name: body.displayName,
      })
      if (result.error) throw result.error
      prepared = result.data
    } else if (body?.action === 'resend') {
      const result = await admin.rpc('prepare_team_invite_resend_as_service', {
        actor_user_id: userData.user.id,
        target_invite_id: body.inviteId,
      })
      if (result.error) throw result.error
      prepared = result.data
    } else if (body?.action === 'reset-unlock-code') {
      if (!Deno.env.get('RESEND_API_KEY') || !Deno.env.get('TEAM_EMAIL_FROM')) {
        return json(503, { error: 'Unlock-code notification delivery is not configured' })
      }
      const tokenPayload = JSON.parse(atob(authorization.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')))
      if (!tokenPayload.iat || Date.now() / 1000 - tokenPayload.iat > 600) {
        return json(401, { error: 'Recent identity verification is required' })
      }
      const result = await admin.rpc('prepare_unlock_reset_as_service', {
        actor_user_id: userData.user.id,
        target_team_id: body.teamId,
        reset_reason: body.reason,
      })
      if (result.error) throw result.error
      prepared = result.data
      await deliverUnlockReset(prepared)
      return json(200, {
        delivered: true,
        message: 'Unlock code rotated and sent to eligible team captains.',
      })
    } else {
      return json(400, { error: 'Unsupported action' })
    }

    const delivery = await deliverInvite(prepared, admin)
    return json(200, {
      inviteId: prepared.inviteId,
      playerId: prepared.playerId,
      playerName: prepared.playerName,
      delivered: delivery.delivered,
      message: delivery.delivered
        ? 'Invite email sent.'
        : 'Invite saved. Email delivery is disabled until provider secrets are configured.',
    })
  } catch (error) {
    // Never log request bodies, tokens, recipients, OTPs, or unlock codes.
    console.error('team-communications request failed', { name: error?.name })
    return json(400, { error: error?.message ?? 'Communication request failed' })
  }
})
