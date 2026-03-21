import { useMemo, useState } from 'react'
import { Btn, Input, Sel, Badge } from '../App'
import * as db from '../lib/db'
import * as auth from '../lib/auth'

const methodLabel = method => method === 'whatsapp' ? 'WhatsApp' : 'Email'

export default function AuthGate({ players, setPlayers, onAuthenticated }) {
  const [mode, setMode] = useState('signin')
  const [method, setMethod] = useState('email')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [step, setStep] = useState('details')
  const [otp, setOtp] = useState('')
  const [pending, setPending] = useState(null)

  const [registerForm, setRegisterForm] = useState({
    name: '',
    email: '',
    mobile: '',
    preferredAuthMethod: 'email',
  })

  const [signinForm, setSigninForm] = useState({
    email: '',
    mobile: '',
  })

  const methodOptions = useMemo(() => [
    { value: 'email', label: 'Email OTP' },
    { value: 'whatsapp', label: 'WhatsApp OTP' },
  ], [])

  const sendOtpByMethod = async ({ method, email, mobile }) => {
    if (method === 'whatsapp') {
      await auth.sendWhatsAppOtp(mobile)
      return
    }
    await auth.sendEmailOtp(email)
  }

  const handleRegister = async () => {
    const name = registerForm.name.trim()
    const email = registerForm.email.trim().toLowerCase()
    const mobile = registerForm.mobile.trim()
    const preferredAuthMethod = registerForm.preferredAuthMethod === 'whatsapp' ? 'whatsapp' : 'email'

    if (!name) return setError('Name is required.')
    if (!email) return setError('Email is required for new players.')
    if (preferredAuthMethod === 'email' && !email) return setError('Default method is Email but email is missing.')
    if (preferredAuthMethod === 'whatsapp' && !mobile) return setError('Default method is WhatsApp but mobile is missing.')

    setLoading(true); setError('')
    try {
      const existingByEmail = email ? await db.findPlayerByAuth({ method: 'email', value: email }) : null
      const existingByMobile = mobile ? await db.findPlayerByAuth({ method: 'whatsapp', value: mobile }) : null

      if (existingByEmail && existingByMobile && existingByEmail.id !== existingByMobile.id) {
        throw new Error('That email and mobile belong to different existing players. Use Sign in or contact an admin.')
      }

      let player = existingByEmail || existingByMobile
      if (!player) {
        player = await db.addPlayer({
          name,
          email,
          mobile,
          preferredAuthMethod,
        })

        setPlayers(prev => [...prev, player].sort((a, b) => a.name.localeCompare(b.name)))
      }

      const sendMethod = method === 'whatsapp' ? (mobile ? 'whatsapp' : 'email') : (email ? 'email' : 'whatsapp')
      await sendOtpByMethod({ method: sendMethod, email, mobile })

      setPending({ player, method: sendMethod, email, mobile })
      setStep('otp')
    } catch (err) {
      setError(err?.message ?? 'Registration failed')
    } finally {
      setLoading(false)
    }
  }

  const handleSignIn = async () => {
    const value = method === 'whatsapp' ? signinForm.mobile.trim() : signinForm.email.trim().toLowerCase()
    if (!value) return setError(`Enter your ${method === 'whatsapp' ? 'mobile number' : 'email address'}.`)

    setLoading(true); setError('')
    try {
      const player = await db.findPlayerByAuth({ method, value })
      if (!player) throw new Error('No player found for that login. Register first in this app.')

      const email = player.email?.trim().toLowerCase() ?? ''
      const mobile = player.mobile?.trim() ?? ''

      if (method === 'email' && !email) throw new Error('This player has no email address saved.')
      if (method === 'whatsapp' && !mobile) throw new Error('This player has no mobile number saved.')

      await sendOtpByMethod({ method, email, mobile })
      setPending({ player, method, email, mobile })
      setStep('otp')
    } catch (err) {
      setError(err?.message ?? 'Sign in failed')
    } finally {
      setLoading(false)
    }
  }

  const verifyOtp = async () => {
    if (!pending) return
    if (!otp.trim()) return setError('Enter the one-time passcode.')

    setLoading(true); setError('')
    try {
      if (pending.method === 'whatsapp') {
        await auth.verifyWhatsAppOtp(pending.mobile, otp)
      } else {
        const data = await auth.verifyEmailOtp(pending.email, otp)
        const authUserId = data?.user?.id
        if (authUserId && pending.player.authUserId !== authUserId) {
          const claimedPlayer = pending.email ? await db.findPlayerByEmail(pending.email) : null
          const playerToLink = claimedPlayer?.id ?? pending.player.id
          const updated = await db.linkPlayerToAuthUser({ playerId: playerToLink, authUserId })
          pending.player = updated
          setPlayers(prev => {
            const withoutPending = prev.filter(p => p.id !== pending.player.id && p.id !== updated.id)
            return [...withoutPending, updated].sort((a, b) => a.name.localeCompare(b.name))
          })
        }
      }
      onAuthenticated(pending.player)
    } catch (err) {
      setError(err?.message ?? 'Code verification failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-zinc-950 text-white px-4 py-8">
      <div className="max-w-lg mx-auto">
        <h1 className="font-display text-2xl font-bold mb-1">White Horse Sign In</h1>
        <p className="text-zinc-400 text-sm mb-5">Authenticate with one-time passcodes by email or WhatsApp.</p>

        <div className="flex gap-1 mb-4 bg-zinc-800 rounded-xl p-1">
          {['signin', 'register'].map(m => (
            <button key={m} onClick={() => { setMode(m); setError(''); setStep('details') }}
              className={`flex-1 py-2 rounded-lg text-xs font-bold capitalize transition-all ${mode === m ? 'bg-amber-500 text-zinc-900' : 'text-zinc-400 hover:text-white'}`}>
              {m}
            </button>
          ))}
        </div>

        {step === 'details' && (
          <div className="bg-zinc-900 border border-zinc-700 rounded-2xl p-4">
            <Sel label="Authentication Method" value={method} onChange={e => setMethod(e.target.value)}>
              {methodOptions.map(opt => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
            </Sel>

            {mode === 'register' ? (
              <>
                <Input label="Name" value={registerForm.name} onChange={e => setRegisterForm(f => ({ ...f, name: e.target.value }))} placeholder="Player name" />
                <Input label="Email" type="email" value={registerForm.email} onChange={e => setRegisterForm(f => ({ ...f, email: e.target.value }))} placeholder="name@example.com" />
                <Input label="Mobile (optional)" value={registerForm.mobile} onChange={e => setRegisterForm(f => ({ ...f, mobile: e.target.value }))} placeholder="+447700900123" />
                <Sel label="Default Authentication Method" value={registerForm.preferredAuthMethod} onChange={e => setRegisterForm(f => ({ ...f, preferredAuthMethod: e.target.value }))}>
                  {methodOptions.map(opt => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
                </Sel>
                <Btn className="w-full" onClick={handleRegister} disabled={loading}>{loading ? 'Working...' : 'Register and Send OTP'}</Btn>
              </>
            ) : (
              <>
                {method === 'email' ? (
                  <Input label="Email" type="email" value={signinForm.email} onChange={e => setSigninForm(f => ({ ...f, email: e.target.value }))} placeholder="name@example.com" />
                ) : (
                  <Input label="Mobile" value={signinForm.mobile} onChange={e => setSigninForm(f => ({ ...f, mobile: e.target.value }))} placeholder="+447700900123" />
                )}
                <Btn className="w-full" onClick={handleSignIn} disabled={loading}>{loading ? 'Working...' : 'Send OTP'}</Btn>
              </>
            )}
          </div>
        )}

        {step === 'otp' && pending && (
          <div className="bg-zinc-900 border border-zinc-700 rounded-2xl p-4">
            <div className="mb-3 text-sm text-zinc-300">Code sent via <Badge color="blue">{methodLabel(pending.method)}</Badge></div>
            <div className="text-xs text-zinc-500 mb-3">{pending.method === 'email' ? pending.email : pending.mobile}</div>
            <Input label="One-time passcode" value={otp} onChange={e => setOtp(e.target.value)} placeholder="6-digit code" />
            {pending.method === 'email' && (
              <p className="text-xs text-zinc-500 mb-3">Enter the 6-digit code from your email (do not click a magic link).</p>
            )}
            <div className="flex gap-2">
              <Btn className="flex-1" onClick={verifyOtp} disabled={loading}>{loading ? 'Verifying...' : 'Verify and Continue'}</Btn>
              <Btn className="flex-1" variant="ghost" onClick={() => { setStep('details'); setOtp(''); setPending(null) }}>Back</Btn>
            </div>
          </div>
        )}

        {error && <p className="mt-3 text-sm text-red-400">{error}</p>}
        <p className="mt-4 text-xs text-zinc-500">WhatsApp OTP requires Twilio webhook endpoints configured in app env.</p>
        <p className="mt-1 text-xs text-zinc-500">Existing players: {players.length}</p>
      </div>
    </div>
  )
}
