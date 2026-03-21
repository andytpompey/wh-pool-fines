import { useState, useEffect, useCallback, useMemo } from 'react'
import * as db from './lib/db'
import * as auth from './lib/auth'
import { resolveCurrentTeamContext } from './lib/currentTeam'
import { resolveAuthenticatedPlayerContext } from './lib/memberships'
import SetupTab from './components/SetupTab'
import MatchesTab from './components/MatchesTab'
import FinesTab   from './components/FinesTab'
import Dashboard  from './components/Dashboard'
import AuthGate   from './components/AuthGate'

export const ADMIN_PIN = '1234'
export const SUB_AMOUNT = 0.50
const LAST_UPDATED = import.meta.env.VITE_LAST_UPDATED
const APP_BANNER_PATHS = [
  '/images/roo-bin-banner.png',
  '/images/roo-bin-banner.png.PNG',
  '/images/roo-bin-banner.PNG',
]
const TEAM_STORAGE_KEY = 'wh_current_team_id'

function formatLastUpdated(value) {
  if (!value) return 'Not available'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'Not available'
  return date.toLocaleString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}

function getRoute() {
  const path = window.location.pathname || '/'
  if (path === '/teams') return { name: 'teams', teamId: null }
  const match = path.match(/^\/teams\/([^/]+)$/)
  if (match) return { name: 'team', teamId: decodeURIComponent(match[1]) }
  return { name: 'app', teamId: null }
}

function navigate(path, { replace = false } = {}) {
  const method = replace ? 'replaceState' : 'pushState'
  window.history[method]({}, '', path)
  window.dispatchEvent(new PopStateEvent('popstate'))
}

export function uuid() {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }

  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    return ([1e7] + -1e3 + -4e3 + -8e3 + -1e11).replace(/[018]/g, c =>
      (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
    )
  }

  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.random() * 16 | 0
    const v = c === 'x' ? r : (r & 0x3 | 0x8)
    return v.toString(16)
  })
}

export function formatDate(dateStr) {
  if (!dateStr) return ''
  return new Date(dateStr + 'T12:00:00').toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

export function Badge({ children, color = 'green' }) {
  const colors = {
    green: 'bg-emerald-900/60 text-emerald-300 border-emerald-700',
    red: 'bg-red-900/60 text-red-300 border-red-700',
    amber: 'bg-amber-900/60 text-amber-300 border-amber-700',
    blue: 'bg-blue-900/60 text-blue-300 border-blue-700',
    gray: 'bg-zinc-800 text-zinc-400 border-zinc-600',
  }
  return <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-bold border ${colors[color]}`}>{children}</span>
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
      <input className="w-full bg-zinc-800 border border-zinc-600 rounded-lg px-3 py-2.5 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-500 text-sm" {...props} />
    </div>
  )
}

export function Sel({ label, children, ...props }) {
  return (
    <div className="mb-3">
      {label && <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-1">{label}</label>}
      <select className="w-full bg-zinc-800 border border-zinc-600 rounded-lg px-3 py-2.5 text-white focus:outline-none focus:border-amber-500 text-sm" {...props}>{children}</select>
    </div>
  )
}

export function Btn({ children, variant = 'primary', size = 'md', className = '', ...props }) {
  const base = 'font-bold rounded-lg transition-all active:scale-95 inline-flex items-center justify-center gap-1 disabled:opacity-50'
  const variants = {
    primary: 'bg-amber-500 hover:bg-amber-400 text-zinc-900',
    danger: 'bg-red-600 hover:bg-red-500 text-white',
    ghost: 'bg-zinc-700 hover:bg-zinc-600 text-white',
    success: 'bg-emerald-600 hover:bg-emerald-500 text-white',
    outline: 'border border-zinc-600 hover:border-zinc-400 text-zinc-300 hover:text-white bg-transparent',
  }
  const sizes = { sm: 'px-3 py-1.5 text-xs', md: 'px-4 py-2 text-sm', lg: 'px-5 py-3 text-base' }
  return <button className={`${base} ${variants[variant]} ${sizes[size]} ${className}`} {...props}>{children}</button>
}

function Spinner() {
  return <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4"><div className="w-10 h-10 border-4 border-zinc-700 border-t-amber-500 rounded-full animate-spin" /><p className="text-zinc-500 text-sm">Loading saved data...</p></div>
}

function ErrorScreen({ error, onRetry }) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4 px-6 text-center">
      <div className="text-4xl">⚠️</div>
      <p className="text-white font-bold">Failed to connect to database</p>
      <p className="text-zinc-400 text-sm">{error}</p>
      <Btn onClick={onRetry}>Retry</Btn>
    </div>
  )
}

function TeamSwitcher({ memberships, currentTeamId, onSwitchTeam, onViewTeams }) {
  if (!memberships.length) return null

  return (
    <div className="bg-zinc-900/80 border border-zinc-800 rounded-xl p-3 mb-4">
      <div className="flex items-center justify-between gap-2 mb-2">
        <div>
          <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">Current team</p>
          <p className="text-sm text-white">Switch context safely without leaving the app.</p>
        </div>
        <Btn size="sm" variant="outline" onClick={onViewTeams}>My Teams</Btn>
      </div>
      <select
        value={currentTeamId ?? ''}
        onChange={event => onSwitchTeam(event.target.value)}
        className="w-full bg-zinc-800 border border-zinc-600 rounded-lg px-3 py-2.5 text-white focus:outline-none focus:border-amber-500 text-sm"
      >
        {memberships.map(membership => (
          <option key={membership.team.id} value={membership.team.id}>
            {membership.team.name} · {membership.role}
          </option>
        ))}
      </select>
    </div>
  )
}

function TeamsIndex({ memberships, currentTeamId, onSwitchTeam, onOpenTeam }) {
  return (
    <div className="space-y-3">
      <div>
        <h2 className="font-display text-2xl font-bold text-white">My Teams</h2>
        <p className="text-sm text-zinc-400">Choose a team to enter, or switch your app-wide team context.</p>
      </div>
      {!memberships.length && (
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 text-sm text-zinc-400">
          You do not currently belong to any teams yet.
        </div>
      )}
      {memberships.map(membership => {
        const isCurrent = membership.team.id === currentTeamId
        return (
          <div key={membership.team.id} className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <div className="flex items-center gap-2 flex-wrap">
                  <h3 className="font-bold text-white">{membership.team.name}</h3>
                  {isCurrent && <Badge color="amber">Current</Badge>}
                  <Badge color="blue">{membership.role}</Badge>
                </div>
                <p className="text-xs text-zinc-500 mt-1">Joined {new Date(membership.joinedAt).toLocaleDateString('en-GB')}</p>
              </div>
            </div>
            <div className="flex gap-2 mt-4">
              <Btn className="flex-1" onClick={() => onOpenTeam(membership.team.id)}>Open team</Btn>
              {!isCurrent && <Btn variant="outline" className="flex-1" onClick={() => onSwitchTeam(membership.team.id)}>Set current</Btn>}
            </div>
          </div>
        )
      })}
    </div>
  )
}

function TeamOverview({ team, onOpenApp, onBackToTeams, membershipCount }) {
  if (!team) {
    return (
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 text-sm text-zinc-400">
        Team not found.
      </div>
    )
  }

  return (
    <div className="space-y-3">
      <div className="flex gap-2">
        <Btn variant="outline" size="sm" onClick={onBackToTeams}>← My Teams</Btn>
        <Btn size="sm" onClick={onOpenApp}>Open app</Btn>
      </div>
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center gap-2 mb-2">
          <h2 className="font-display text-2xl font-bold text-white">{team.name}</h2>
          <Badge color="amber">Current team</Badge>
        </div>
        <div className="space-y-1 text-sm text-zinc-400">
          <p>Join code: <span className="text-white font-medium">{team.joinCode || 'Not available'}</span></p>
          <p>Members visible in your profile: <span className="text-white font-medium">{membershipCount}</span></p>
        </div>
        <p className="text-xs text-zinc-500 mt-4">
          Existing dashboard, matches, fines, and setup screens continue to use this selected team where team scoping exists.
        </p>
      </div>
    </div>
  )
}

export default function App() {
  const [tab, setTab] = useState(0)
  const [route, setRoute] = useState(() => getRoute())
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState('')
  const [authLoading, setAuthLoading] = useState(true)
  const [session, setSession] = useState(null)
  const [profile, setProfile] = useState(null)
  const [memberContext, setMemberContext] = useState({ profile: null, memberships: [], player: null })
  const [currentTeamId, setCurrentTeamId] = useState(() => localStorage.getItem(TEAM_STORAGE_KEY) || null)
  const [showBanner, setShowBanner] = useState(true)
  const [bannerPathIndex, setBannerPathIndex] = useState(0)
  const [players, setPlayers] = useState([])
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

  const load = useCallback((teamId) => {
    setLoading(true)
    setError(null)
    db.loadAll({ teamId }).then(data => {
      setPlayers(data.players)
      setFineTypes(data.fineTypes)
      setSeasons(data.seasons)
      setMatches(data.matches)
      setLoading(false)
    }).catch(err => {
      setError(err.message ?? String(err))
      setLoading(false)
    })
  }, [])

  useEffect(() => {
    const handleRouteChange = () => setRoute(getRoute())
    window.addEventListener('popstate', handleRouteChange)
    return () => window.removeEventListener('popstate', handleRouteChange)
  }, [])

  useEffect(() => {
    auth.getSession()
      .then(currentSession => {
        setSession(currentSession)
      })
      .catch(() => setSession(null))
      .finally(() => setAuthLoading(false))

    const unsubscribe = auth.onAuthStateChange(nextSession => setSession(nextSession))
    return unsubscribe
  }, [])

  useEffect(() => {
    let cancelled = false

    if (!session?.user) {
      setProfile(null)
      setMemberContext({ profile: null, memberships: [], player: null })
      setCurrentTeamId(null)
      return
    }

    resolveAuthenticatedPlayerContext({ user: session.user })
      .then(context => {
        if (cancelled) return
        setProfile(context.profile)
        setMemberContext(context)

        const resolvedTeamId = resolveCurrentTeamContext({
          routeTeamId: route.teamId,
          storedTeamId: localStorage.getItem(TEAM_STORAGE_KEY),
          memberships: context.memberships,
        })
        setCurrentTeamId(resolvedTeamId)

        if (route.name === 'team' && resolvedTeamId && route.teamId !== resolvedTeamId) {
          navigate(`/teams/${resolvedTeamId}`, { replace: true })
        }
      })
      .catch(err => {
        console.error('Profile and membership resolution failed', err)
      })

    return () => {
      cancelled = true
    }
  }, [session?.user?.id, route.name, route.teamId])

  useEffect(() => {
    if (route.name === 'team' && route.teamId && route.teamId !== currentTeamId) {
      setCurrentTeamId(route.teamId)
    }
  }, [route.name, route.teamId])

  useEffect(() => {
    if (session && currentTeamId) load(currentTeamId)
  }, [session, currentTeamId, load])

  useEffect(() => {
    if (currentPlayer) localStorage.setItem('wh_current_player', JSON.stringify(currentPlayer))
    else localStorage.removeItem('wh_current_player')
  }, [currentPlayer])

  useEffect(() => {
    if (currentTeamId) localStorage.setItem(TEAM_STORAGE_KEY, currentTeamId)
    else localStorage.removeItem(TEAM_STORAGE_KEY)
  }, [currentTeamId])

  const currentTeamMembership = useMemo(
    () => memberContext.memberships.find(membership => membership.team.id === currentTeamId) ?? null,
    [memberContext.memberships, currentTeamId],
  )

  const switchTeam = useCallback((teamId, destination = 'app') => {
    const allowed = memberContext.memberships.some(membership => membership.team.id === teamId)
    if (!allowed) return
    setCurrentTeamId(teamId)
    const path = destination === 'team' ? `/teams/${teamId}` : '/'
    navigate(path)
  }, [memberContext.memberships])

  const withSave = async (fn) => {
    setSaving(true)
    setSaveError('')
    try {
      await fn()
    } catch (err) {
      setSaveError(err?.message ?? 'Failed to save changes')
      console.error('Save failed:', err)
    } finally {
      setSaving(false)
    }
  }

  const handleSignOut = async () => {
    try {
      await auth.signOut()
      setSession(null)
      setProfile(null)
      setCurrentPlayer(null)
      setCurrentTeamId(null)
      setMemberContext({ profile: null, memberships: [], player: null })
      navigate('/', { replace: true })
    } catch (err) {
      console.error('Sign-out failed:', err)
    }
  }

  const tabLabels = ['Dashboard', 'Matches', 'Fines', 'Setup']
  const icons = ['📊', '🎱', '💰', '⚙️']

  if (authLoading) return <Spinner />

  return (
    <div className="min-h-screen bg-zinc-950 text-white pb-24">
      <div className="bg-zinc-950/95 border-b border-zinc-800">
        {showBanner && (
          <div className="max-w-lg mx-auto">
            <img
              src={APP_BANNER_PATHS[bannerPathIndex]}
              alt="Roo Bin banner"
              className="h-36 sm:h-44 w-full bg-zinc-950 object-contain object-center"
              onError={() => {
                if (bannerPathIndex < APP_BANNER_PATHS.length - 1) {
                  setBannerPathIndex(prev => prev + 1)
                  return
                }
                setShowBanner(false)
              }}
            />
          </div>
        )}
        <div className="max-w-lg mx-auto px-4 pb-3 flex items-center justify-between gap-3">
          <div className="inline-flex items-center gap-2 text-xs text-zinc-300 bg-zinc-900/80 border border-zinc-700 rounded-md px-2.5 py-1">
            <span className="text-amber-400">🕒</span>
            <span>Last updated: {formatLastUpdated(LAST_UPDATED)}</span>
          </div>
          {currentPlayer && (
            <button onClick={handleSignOut} className="text-xs text-zinc-300 hover:text-white bg-zinc-800 border border-zinc-700 rounded-full px-3 py-1.5 whitespace-nowrap">
              Sign out
            </button>
          )}
        </div>
      </div>

      {!currentPlayer ? (
        <AuthGate players={players} setPlayers={setPlayers} onAuthenticated={setCurrentPlayer} />
      ) : (
        <>
          <div className="max-w-lg mx-auto px-4 pt-4">
            {!!saveError && <div className="mb-3 text-sm text-red-400 bg-red-950/40 border border-red-800/50 rounded-xl px-3 py-2">{saveError}</div>}
            <TeamSwitcher
              memberships={memberContext.memberships}
              currentTeamId={currentTeamId}
              onSwitchTeam={teamId => switchTeam(teamId, route.name === 'team' ? 'team' : 'app')}
              onViewTeams={() => navigate('/teams')}
            />

            {!currentTeamId ? (
              <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 text-sm text-zinc-400">
                No current team is available for this account yet.
              </div>
            ) : loading ? <Spinner /> : error ? <ErrorScreen error={error} onRetry={() => load(currentTeamId)} /> : route.name === 'teams' ? (
              <TeamsIndex
                memberships={memberContext.memberships}
                currentTeamId={currentTeamId}
                onSwitchTeam={teamId => switchTeam(teamId, 'app')}
                onOpenTeam={teamId => switchTeam(teamId, 'team')}
              />
            ) : route.name === 'team' ? (
              <TeamOverview
                team={currentTeamMembership?.team}
                membershipCount={memberContext.memberships.length}
                onOpenApp={() => navigate('/')}
                onBackToTeams={() => navigate('/teams')}
              />
            ) : (
              <>
                <div className="mb-4 bg-zinc-900/70 border border-zinc-800 rounded-xl px-3 py-2 text-xs text-zinc-400">
                  Working in <span className="text-white font-bold">{currentTeamMembership?.team.name ?? 'Selected team'}</span>.
                </div>
                {tab === 0 && <Dashboard players={players} fineTypes={fineTypes} seasons={seasons} matches={matches} currentTeam={currentTeamMembership?.team} />}
                {tab === 1 && <MatchesTab players={players} fineTypes={fineTypes} seasons={seasons} matches={matches} setMatches={setMatches} withSave={withSave} currentTeamId={currentTeamId} />}
                {tab === 2 && <FinesTab players={players} matches={matches} setMatches={setMatches} withSave={withSave} currentTeamId={currentTeamId} />}
                {tab === 3 && <SetupTab players={players} fineTypes={fineTypes} seasons={seasons} matches={matches}
                                setPlayers={setPlayers} setFineTypes={setFineTypes} setSeasons={setSeasons} setMatches={setMatches} withSave={withSave}
                                currentUser={session?.user} profile={profile} setProfile={setProfile} currentTeamId={currentTeamId} currentTeam={currentTeamMembership?.team} />}
              </>
            )}
          </div>

          {route.name === 'app' && currentTeamId && (
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
          )}
        </>
      )}

      {(saving && currentPlayer) && (
        <div className="fixed top-4 right-4 z-50 bg-zinc-900 border border-zinc-700 rounded-lg px-3 py-2 text-xs text-zinc-300">
          Saving…
        </div>
      )}
    </div>
  )
}
