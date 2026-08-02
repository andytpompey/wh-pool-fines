import { supabase } from './supabase'

function handleFunctionResult({ data, error }) {
  if (error) throw error
  if (data?.error) throw new Error(data.error)
  return data
}

export async function createAndSendTeamInvite({ teamId, email, displayName }) {
  if (!teamId) throw new Error('Team is required.')
  if (!email?.trim()) throw new Error('Email is required.')
  if (!displayName?.trim()) throw new Error('Display name is required.')

  return handleFunctionResult(await supabase.functions.invoke('team-communications', {
    body: {
      action: 'invite',
      teamId,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
    },
  }))
}

export async function resendTeamInvite(inviteId) {
  if (!inviteId) throw new Error('Invite is required.')
  return handleFunctionResult(await supabase.functions.invoke('team-communications', {
    body: { action: 'resend', inviteId },
  }))
}
