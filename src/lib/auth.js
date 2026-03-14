import { supabase } from './supabase'

const whatsappSendUrl = import.meta.env.VITE_TWILIO_WHATSAPP_OTP_SEND_URL
const whatsappVerifyUrl = import.meta.env.VITE_TWILIO_WHATSAPP_OTP_VERIFY_URL

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
      emailRedirectTo: typeof window !== 'undefined' ? window.location.origin : undefined,
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

async function postWhatsAppOtp(url, payload) {
  if (!url) {
    throw new Error('WhatsApp OTP endpoint is not configured. Set VITE_TWILIO_WHATSAPP_OTP_SEND_URL and VITE_TWILIO_WHATSAPP_OTP_VERIFY_URL.')
  }

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })

  const body = await res.json().catch(() => ({}))
  if (!res.ok) {
    throw new Error(body?.error || 'Failed to process WhatsApp OTP request')
  }

  return body
}

export async function sendWhatsAppOtp(mobile) {
  const normalizedMobile = normalizeMobile(mobile)
  if (!normalizedMobile) throw new Error('Mobile number is required')

  await postWhatsAppOtp(whatsappSendUrl, { mobile: normalizedMobile })
  return normalizedMobile
}

export async function verifyWhatsAppOtp(mobile, token) {
  const normalizedMobile = normalizeMobile(mobile)
  if (!normalizedMobile || !token?.trim()) throw new Error('Mobile number and OTP are required')

  return postWhatsAppOtp(whatsappVerifyUrl, { mobile: normalizedMobile, token: token.trim() })
}

export async function signOut() {
  const { error } = await supabase.auth.signOut()
  if (error) throw error
}
