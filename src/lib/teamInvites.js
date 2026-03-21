const inviteEmailEndpoint = import.meta.env.VITE_TEAM_INVITE_EMAIL_URL

function normaliseEmail(email) {
  return email?.trim().toLowerCase() ?? ''
}

function getRandomBytes(size) {
  const bytes = new Uint8Array(size)
  crypto.getRandomValues(bytes)
  return bytes
}

export function generateSecureInviteToken() {
  return Array.from(getRandomBytes(24), byte => byte.toString(16).padStart(2, '0')).join('')
}

export async function sendTeamInviteEmail({ email, teamName, inviteToken, invitedPlayerName }) {
  const normalizedEmail = normaliseEmail(email)
  if (!normalizedEmail) throw new Error('Email is required.')

  if (!inviteEmailEndpoint) {
    return {
      delivered: false,
      mode: 'placeholder',
      message: 'Invite saved. Email delivery is not configured yet.',
    }
  }

  const response = await fetch(inviteEmailEndpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: normalizedEmail,
      teamName,
      inviteToken,
      invitedPlayerName,
    }),
  })

  const body = await response.json().catch(() => ({}))
  if (!response.ok) {
    throw new Error(body?.error || 'Failed to send team invite email.')
  }

  return {
    delivered: true,
    mode: 'configured',
    message: body?.message || 'Invite email sent.',
  }
}
