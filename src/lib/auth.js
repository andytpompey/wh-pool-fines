import { supabase } from './supabase'

function normalizeEmail(email) {
  return email?.trim().toLowerCase() ?? ''
}

function normalizeMobile(mobile) {
  return mobile?.trim() ?? ''
}

export async function sendEmailOtp(email) {
  const normalizedEmail = normalizeEmail(email)
  if (!normalizedEmail) throw new Error('Email is required')

  const { error } = await supabase.auth.signInWithOtp({
    email: normalizedEmail,
    options: {
      shouldCreateUser: true,
      emailRedirectTo: window.location.href,
    },
  })

  if (error) throw error
  return normalizedEmail
}

export async function verifyEmailOtp(email, token) {
  const normalizedEmail = normalizeEmail(email)
  if (!normalizedEmail || !token?.trim()) throw new Error('Email and OTP are required')

  const { data, error } = await supabase.auth.verifyOtp({
    email: normalizedEmail,
    token: token.trim(),
    type: 'email',
  })

  if (error) throw error
  return data
}

export async function sendWhatsAppOtp(mobile) {
  const normalizedMobile = normalizeMobile(mobile)
  if (!normalizedMobile) throw new Error('Mobile number is required')

  const { error } = await supabase.auth.signInWithOtp({
    phone: normalizedMobile,
    options: {
      channel: 'whatsapp',
      shouldCreateUser: true,
    },
  })
  if (error) throw error
  return normalizedMobile
}

export async function verifyWhatsAppOtp(mobile, token) {
  const normalizedMobile = normalizeMobile(mobile)
  if (!normalizedMobile || !token?.trim()) throw new Error('Mobile number and OTP are required')

  const { data, error } = await supabase.auth.verifyOtp({
    phone: normalizedMobile,
    token: token.trim(),
    type: 'sms',
  })
  if (error) throw error
  return data
}

export async function signOut() {
  const { error } = await supabase.auth.signOut()
  if (error) throw error
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
