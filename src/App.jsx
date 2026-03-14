import { useState, useEffect, useCallback } from 'react'
import * as db from './lib/db'
import SetupTab   from './components/SetupTab'
import MatchesTab from './components/MatchesTab'
import FinesTab   from './components/FinesTab'
import Dashboard  from './components/Dashboard'
import AuthGate   from './components/AuthGate'
import * as auth from './lib/auth'

// ─── Constants ────────────────────────────────────────────────────────────────
export const ADMIN_PIN  = '1234'
export const SUB_AMOUNT = 0.50
const LAST_UPDATED = import.meta.env.VITE_LAST_UPDATED

function formatLastUpdated(value) {
  if (!value) return 'Not available'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'Not available'
  return date.toLocaleString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

// ─── Utilities ────────────────────────────────────────────────────────────────
export function uuid() {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }

  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    return ([1e7] + -1e3 + -4e3 + -8e3 + -1e11).replace(/[018]/g, c =>
      (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
    )
  }

  // Last resort fallback for very old environments.
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.random() * 16 | 0
    const v = c === 'x' ? r : (r & 0x3 | 0x8)
    return v.toString(16)
  })
}

export function formatDate(dateStr) {
  if (!dateStr) return ''
  return new Date(dateStr + 'T12:00:00').toLocaleDateString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric',
  })
}

// ─── UI Primitives ────────────────────────────────────────────────────────────
export function Badge({ children, color = 'green' }) {
  const colors = {
    green: 'bg-emerald-900/60 text-emerald-300 border-emerald-700',
    red:   'bg-red-900/60 text-red-300 border-red-700',
    amber: 'bg-amber-900/60 text-amber-300 border-amber-700',
    blue:  'bg-blue-900/60 text-blue-300 border-blue-700',
    gray:  'bg-zinc-800 text-zinc-400 border-zinc-600',
  }
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-bold border ${colors[color]}`}>
      {children}
    </span>
  )
}

export function Modal({ title, onClose, children }) {
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <div className="bg-zinc-900 border border-zinc-700 rounded-2xl w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between p-4 border-b border-zinc-700">
          <h2 className="font-display text-lg font-bold text-white">{title}</h2>
          <button onClick={onClose} className="text-zinc-400 hover:text-white text-2xl leading-none">×</button>
        </div>
        <div className="p-4">{children}</div>
      </div>
    </div>
  )
}

export function Input({ label, ...props }) {
  return (
    <div className="mb-3">
      {label && <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-1">{label}</label>}
      <input
        className="w-full bg-zinc-800 border border-zinc-600 rounded-lg px-3 py-2.5 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-500 text-sm"
        {...props}
      />
    </div>
  )
}

export function Sel({ label, children, ...props }) {
  return (
    <div className="mb-3">
      {label && <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-1">{label}</label>}
      <select
        className="w-full bg-zinc-800 border border-zinc-600 rounded-lg px-3 py-2.5 text-white focus:outline-none focus:border-amber-500 text-sm"
        {...props}
      >
        {children}
      </select>
    </div>
  )
}

export function Btn({ children, variant = 'primary', size = 'md', className = '', ...props }) {
  const base = 'font-bold rounded-lg transition-all active:scale-95 inline-flex items-center justify-center gap-1 disabled:opacity-50'
  const variants = {
    primary: 'bg-amber-500 hover:bg-amber-400 text-zinc-900',
    danger:  'bg-red-600 hover:bg-red-500 text-white',
    ghost:   'bg-zinc-700 hover:bg-zinc-600 text-white',
    success: 'bg-emerald-600 hover:bg-emerald-500 text-white',
    outline: 'border border-zinc-600 hover:border-zinc-400 text-zinc-300 hover:text-white bg-transparent',
  }
  const sizes = { sm: 'px-3 py-1.5 text-xs', md: 'px-4 py-2 text-sm', lg: 'px-5 py-3 text-base' }
  return (
    <button className={`${base} ${variants[variant]} ${sizes[size]} ${className}`} {...props}>
      {children}
    </button>
  )
}

function Spinner() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
      <div className="w-10 h-10 border-4 border-zinc-700 border-t-amber-500 rounded-full animate-spin" />
      <p className="text-zinc-500 text-sm">Loading saved data...</p>
    </div>
  )
}

function ErrorScreen({ error, onRetry }) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4 px-6 text-center">
      <div className="text-4xl">⚠️</div>
      <p className="text-white font-bold">Failed to connect to database</p>
      <p className="text-zinc-400 text-sm">{error}</p>
      <p className="text-zinc-500 text-xs">Check your .env file has the correct Supabase URL and anon key.</p>
      <Btn onClick={onRetry}>Retry</Btn>
    </div>
  )
}

// ─── Root App ─────────────────────────────────────────────────────────────────
export default function App() {
  const [tab,       setTab]       = useState(0)
  const [loading,   setLoading]   = useState(true)
  const [error,     setError]     = useState(null)
  const [saving,    setSaving]    = useState(false)
  const [saveError, setSaveError] = useState('')
  const [players,   setPlayers]   = useState([])
  const [fineTypes, setFineTypes] = useState([])
  const [seasons,   setSeasons]   = useState([])
  const [matches,   setMatches]   = useState([])
  const [currentPlayer, setCurrentPlayer] = useState(() => {
    try {
      const raw = localStorage.getItem('wh_current_player')
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  })

  const load = useCallback(() => {
    setLoading(true)
    setError(null)
    db.loadAll()
      .then(data => {
        setPlayers(data.players)
        setFineTypes(data.fineTypes)
        setSeasons(data.seasons)
        setMatches(data.matches)
        setLoading(false)
      })
      .catch(err => {
        setError(err.message ?? String(err))
        setLoading(false)
      })
  }, [])

  useEffect(() => { load() }, [load])


  useEffect(() => {
    if (currentPlayer) localStorage.setItem('wh_current_player', JSON.stringify(currentPlayer))
    else localStorage.removeItem('wh_current_player')
  }, [currentPlayer])

  const handleSignOut = async () => {
    try {
      await auth.signOut()
    } catch (err) {
      console.warn('Signout warning:', err)
    }
    setCurrentPlayer(null)
  }

  const withSave = async (fn) => {
    setSaving(true)
    setSaveError('')
    try {
      await fn()
    } catch (err) {
      const message = err?.message ?? 'Failed to save changes'
      setSaveError(message)
      console.error('Save failed:', err)
    } finally {
      setSaving(false)
    }
  }

  const tabLabels = ['Dashboard', 'Matches', 'Fines', 'Setup']
  const icons     = ['📊', '🎱', '💰', '⚙️']

  return (
    <div className="min-h-screen bg-zinc-950 text-white pb-24">
      {/* Header */}
      <div className="sticky top-0 z-40 bg-zinc-950/95 backdrop-blur border-b border-zinc-800">
        <div className="max-w-lg mx-auto px-4 py-3 flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-amber-500 flex items-center justify-center text-zinc-900 font-bold text-xs">WH</div>
          <div className="flex-1">
            <div className="font-display font-bold text-white text-lg leading-none">White Horse</div>
            <div className="text-zinc-500 text-xs">Pool Fines Tracker</div>
            <div className="text-zinc-600 text-[10px] mt-0.5">Last updated: {formatLastUpdated(LAST_UPDATED)}</div>
            {currentPlayer && <div className="text-zinc-400 text-[11px] mt-0.5">Signed in: {currentPlayer.name}</div>}
          </div>
          {currentPlayer && (
            <button onClick={handleSignOut} className="text-xs text-zinc-300 hover:text-white bg-zinc-800 border border-zinc-700 rounded-full px-2 py-1">Sign out</button>
          )}
          {saveError ? (
            <div className="flex items-center gap-1.5 text-xs text-red-300 bg-red-950/60 border border-red-800/70 px-2 py-1 rounded-full">
              <span className="w-1.5 h-1.5 bg-red-400 rounded-full" />
              Save failed
            </div>
          ) : saving ? (
            <div className="flex items-center gap-1.5 text-xs text-amber-400 bg-amber-950/50 border border-amber-800/50 px-2 py-1 rounded-full">
              <span className="w-1.5 h-1.5 bg-amber-400 rounded-full animate-pulse" />
              Saving...
            </div>
          ) : !loading && !error ? (
            <div className="flex items-center gap-1.5 text-xs text-emerald-500 bg-emerald-950/50 border border-emerald-800/50 px-2 py-1 rounded-full">
              <span className="w-1.5 h-1.5 bg-emerald-500 rounded-full" />
              Saved
            </div>
          ) : null}
        </div>
        <div className="max-w-lg mx-auto px-4 pb-2">
          <div className="inline-flex items-center gap-2 text-xs text-zinc-300 bg-zinc-900/80 border border-zinc-700 rounded-md px-2.5 py-1">
            <span className="text-amber-400">🕒</span>
            <span>Last updated: {formatLastUpdated(LAST_UPDATED)}</span>
          </div>
        </div>
      </div>

      {!currentPlayer ? (
        <AuthGate players={players} setPlayers={setPlayers} onAuthenticated={setCurrentPlayer} />
      ) : (
        <>
          {/* Content */}
          <div className="max-w-lg mx-auto px-4 pt-4">
            {loading ? <Spinner /> : error ? <ErrorScreen error={error} onRetry={load} /> : (
              <>
                {tab === 0 && <Dashboard  players={players} fineTypes={fineTypes} seasons={seasons} matches={matches} />}
                {tab === 1 && <MatchesTab players={players} fineTypes={fineTypes} seasons={seasons} matches={matches} setMatches={setMatches} withSave={withSave} />}
                {tab === 2 && <FinesTab   players={players} matches={matches} setMatches={setMatches} withSave={withSave} />}
                {tab === 3 && <SetupTab   players={players} fineTypes={fineTypes} seasons={seasons} matches={matches}
                                setPlayers={setPlayers} setFineTypes={setFineTypes} setSeasons={setSeasons} setMatches={setMatches} withSave={withSave} />}
              </>
            )}
          </div>

          {/* Bottom nav */}
          <div className="fixed bottom-0 left-0 right-0 z-40 bg-zinc-950/95 backdrop-blur border-t border-zinc-800">
            <div className="max-w-lg mx-auto flex">
              {tabLabels.map((t, i) => (
                <button key={t} onClick={() => setTab(i)}
                  className={`flex-1 py-3 flex flex-col items-center gap-0.5 transition-all ${tab === i ? 'text-amber-400' : 'text-zinc-500 hover:text-zinc-300'}`}>
                  <span className="text-lg">{icons[i]}</span>
                  <span className="text-xs font-bold">{t}</span>
                  {tab === i && <div className="w-4 h-0.5 bg-amber-400 rounded-full mt-0.5" />}
                </button>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  )
}
