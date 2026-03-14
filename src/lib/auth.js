import { supabase } from './supabase'

export async function signInWithEmailOtp(email) {
  const normalisedEmail = email?.trim().toLowerCase()
  if (!normalisedEmail) throw new Error('Email is required')

  const { error } = await supabase.auth.signInWithOtp({
    email: normalisedEmail,
    options: { shouldCreateUser: true },
  })

  if (error) throw error
  return normalisedEmail
}

export async function verifyEmailOtp(email, token) {
  const normalisedEmail = email?.trim().toLowerCase()
  if (!normalisedEmail || !token?.trim()) throw new Error('Email and code are required')

  const { data, error } = await supabase.auth.verifyOtp({
    email: normalisedEmail,
    token: token.trim(),
    type: 'email',
  })

  if (error) throw error
  return data
}

export async function signInWithWhatsAppOtp(phone) {
  const normalisedPhone = phone?.trim()
  if (!normalisedPhone) throw new Error('Mobile number is required')

  const { error } = await supabase.auth.signInWithOtp({
    phone: normalisedPhone,
    options: {
      channel: 'whatsapp',
      shouldCreateUser: true,
    },
  })

  if (error) throw error
  return normalisedPhone
}

export async function verifyWhatsAppOtp(phone, token) {
  const normalisedPhone = phone?.trim()
  if (!normalisedPhone || !token?.trim()) throw new Error('Mobile number and code are required')

  const { data, error } = await supabase.auth.verifyOtp({
    phone: normalisedPhone,
    token: token.trim(),
    type: 'sms',
  })

  if (error) throw error
  return data
}

export async function getSession() {
  const { data, error } = await supabase.auth.getSession()
  if (error) throw error
  return data.session
}

export function onAuthStateChange(callback) {
  const { data } = supabase.auth.onAuthStateChange((_event, session) => callback(session))
  return () => data.subscription.unsubscribe()
}

export async function signOut() {
  const { error } = await supabase.auth.signOut()
  if (error) throw error
}
