import { useEffect, useState } from 'react'
import { Btn, Input, Sel, Badge } from '../App'
import * as auth from '../lib/auth'

export default function AuthGate({ session, onSessionReady }) {
  const [method, setMethod] = useState('email')
  const [step, setStep] = useState('contact')
  const [contact, setContact] = useState({ email: '', phone: '' })
  const [otp, setOtp] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [sentTo, setSentTo] = useState('')

  useEffect(() => {
    if (session?.user) onSessionReady(session)
  }, [session, onSessionReady])

  const sendOtp = async () => {
    setError('')
    setLoading(true)

    try {
      if (method === 'whatsapp') {
        const phone = await auth.signInWithWhatsAppOtp(contact.phone)
        setSentTo(phone)
      } else {
        const email = await auth.signInWithEmailOtp(contact.email)
        setSentTo(email)
      }
      setStep('otp')
    } catch (err) {
      setError(err?.message ?? 'Could not send your code.')
    } finally {
      setLoading(false)
    }
  }

  const verifyOtp = async () => {
    setError('')
    setLoading(true)

    try {
      if (method === 'whatsapp') {
        await auth.verifyWhatsAppOtp(contact.phone, otp)
      } else {
        await auth.verifyEmailOtp(contact.email, otp)
      }

      const nextSession = await auth.getSession()
      if (!nextSession) throw new Error('Signed in but no session was returned.')
      onSessionReady(nextSession)
    } catch (err) {
      setError(err?.message ?? 'Could not verify your code.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-zinc-950 text-white px-4 py-8">
      <div className="max-w-lg mx-auto">
        <h1 className="font-display text-2xl font-bold mb-1">Sign in</h1>
        <p className="text-zinc-400 text-sm mb-5">Use a one-time passcode by email or WhatsApp.</p>

        <div className="bg-zinc-900 border border-zinc-700 rounded-2xl p-4">
          <Sel label="Sign-in method" value={method} onChange={e => setMethod(e.target.value)}>
            <option value="email">Email OTP</option>
            <option value="whatsapp">WhatsApp OTP</option>
          </Sel>

          {step === 'contact' ? (
            <>
              {method === 'email' ? (
                <Input
                  label="Email"
                  type="email"
                  value={contact.email}
                  onChange={e => setContact(c => ({ ...c, email: e.target.value }))}
                  placeholder="name@example.com"
                />
              ) : (
                <Input
                  label="Mobile number"
                  value={contact.phone}
                  onChange={e => setContact(c => ({ ...c, phone: e.target.value }))}
                  placeholder="+447700900123"
                />
              )}
              <Btn className="w-full" onClick={sendOtp} disabled={loading}>{loading ? 'Sending…' : 'Send code'}</Btn>
            </>
          ) : (
            <>
              <div className="mb-3 text-sm text-zinc-300">Code sent to <Badge color="blue">{sentTo}</Badge></div>
              <Input
                label="One-time code"
                value={otp}
                onChange={e => setOtp(e.target.value)}
                placeholder="Enter your code"
              />
              <div className="flex gap-2">
                <Btn className="flex-1" onClick={verifyOtp} disabled={loading}>{loading ? 'Verifying…' : 'Verify code'}</Btn>
                <Btn variant="ghost" className="flex-1" onClick={() => { setStep('contact'); setOtp('') }}>Back</Btn>
              </div>
            </>
          )}

          {error && <p className="mt-3 text-sm text-red-400">{error}</p>}
          {method === 'whatsapp' && (
            <p className="mt-3 text-xs text-zinc-500">Enter mobile in E.164 format, for example +447700900123.</p>
          )}
        </div>
      </div>
    </div>
  )
}
