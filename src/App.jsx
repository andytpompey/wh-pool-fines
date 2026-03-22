import { useState, useEffect, useCallback, useMemo } from 'react'
import * as db from './lib/db'
import * as auth from './lib/auth'
import * as teamModel from './lib/teamModel'
import * as userProfileDb from './lib/userProfile'
import * as teamInvites from './lib/teamInvites'
import { TEAM_ROLE, canAssignTeamRole, canEditPlayerProfileInTeam, normaliseTeamRole } from './lib/permissions'
import { APP_ACTION, assertActionAccess, canAccessAction } from './lib/accessControl'
import { resolveCurrentTeamContext } from './lib/currentTeam'
import { resolveAuthenticatedPlayerContext } from './lib/memberships'
import SetupTab from './components/SetupTab'
import MatchesTab from './components/MatchesTab'
import FinesTab   from './components/FinesTab'
import Dashboard  from './components/Dashboard'
import AuthGate   from './components/AuthGate'
import TeamManagementPage from './components/TeamManagementPage'

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
  if (path === '/profile') return { name: 'profile', teamId: null }
  if (path === '/teams/new') return { name: 'create-team', teamId: null }
  if (path === '/teams/join') return { name: 'join-team', teamId: null }
  const match = path.match(/^\/teams\/([^/]+)$/)
  if (match) return { name: 'team', teamId: decodeURIComponent(match[1]) }
  return { name: 'app', teamId: null }
}

function navigate(path, { replace = false } = {}) {
  const method = replace ? 'replaceState' : 'pushState'
  window.history[method]({}, '', path)
  window.dispatchEvent(new PopStateEvent('popstate'))
}

function isMoreRoute(routeName) {
  return ['profile', 'teams', 'create-team', 'join-team', 'team'].includes(routeName)
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

function generateJoinCode() {
  return Math.random().toString(36).slice(2, 8).toUpperCase()
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

export function SegmentedControl({ options, value, onChange, className = '', itemClassName = '', fullWidth = false, scrollable = false }) {
  const containerClassName = [
    'rounded-2xl border border-zinc-800 bg-zinc-900/90 p-1.5',
    scrollable ? 'flex overflow-x-auto gap-2 scrollbar-hide' : 'grid gap-2',
    fullWidth ? 'grid-flow-col auto-cols-fr' : 'grid-flow-col auto-cols-max',
    className,
  ].filter(Boolean).join(' ')

  return (
    <div className={containerClassName}>
      {options.map(option => {
        const isSelected = option.value === value
        const label = option.label ?? option.value
        return (
          <button
            key={option.value}
            type="button"
            onClick={() => onChange(option.value)}
            className={[
              'min-h-10 shrink-0 rounded-xl border px-3.5 py-2 text-xs font-bold leading-none transition-all whitespace-nowrap',
              isSelected
                ? 'border-amber-400/80 bg-amber-500 text-zinc-900 shadow-[0_0_0_1px_rgba(251,191,36,0.2)]'
                : 'border-zinc-800 bg-zinc-800/80 text-zinc-400 hover:border-zinc-700 hover:text-white',
              fullWidth ? 'w-full' : '',
              itemClassName,
            ].filter(Boolean).join(' ')}
          >
            {label}
          </button>
        )
      })}
    </div>
  )
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

function TeamSwitcher({ memberships, currentTeamId, onSwitchTeam }) {
  if (!memberships.length) return null

  const currentMembership = memberships.find(membership => membership.team.id === currentTeamId) ?? memberships[0]

  return (
    <div className="mb-3 rounded-xl border border-zinc-800 bg-zinc-900/80 px-3 py-2.5">
      <div className="flex items-center gap-2 mb-2">
        <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-zinc-500">Team</p>
        {currentMembership && <Badge color="amber">{teamModel.getRoleLabel(currentMembership.role)}</Badge>}
      </div>
      <select
        value={currentTeamId ?? ''}
        onChange={event => onSwitchTeam(event.target.value)}
        className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-amber-500 text-sm"
      >
        {memberships.map(membership => (
          <option key={membership.team.id} value={membership.team.id}>
            {membership.team.name} · {teamModel.getRoleLabel(membership.role)}
          </option>
        ))}
      </select>
    </div>
  )
}

function TeamsIndex({ memberships, currentTeamId, onOpenTeam, onCreateTeam, onJoinTeam }) {
  const currentMembership = memberships.find(membership => membership.team.id === currentTeamId) ?? null

  return (
    <div className="space-y-4">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">More &gt; Teams</p>
            <h2 className="font-display text-2xl font-bold text-white mt-1">Teams</h2>
            <p className="text-sm text-zinc-400 mt-1">Review your teams and open one for deeper management when needed. Change the active app-wide team from Profile.</p>
          </div>
          <div className="flex flex-col gap-2 sm:flex-row">
            <Btn size="sm" variant="outline" onClick={onJoinTeam}>Join team</Btn>
            <Btn size="sm" onClick={onCreateTeam}>Create team</Btn>
          </div>
        </div>
      </div>

      <div className="bg-zinc-900/70 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">Active team context</p>
            <p className="text-sm text-zinc-400 mt-1">Dashboard, Matches, and Fines continue to use the current team shown below. Switch it from Profile whenever needed.</p>
          </div>
          <Badge color={currentMembership ? 'amber' : 'gray'}>{currentMembership ? 'Current' : 'No team'}</Badge>
        </div>
        <div className="mt-3 rounded-xl border border-zinc-800 bg-zinc-950/60 px-4 py-3">
          {currentMembership ? (
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="flex items-center gap-2 flex-wrap">
                  <p className="text-base font-bold text-white">{currentMembership.team.name}</p>
                  <Badge color="amber">Current</Badge>
                </div>
                <p className="text-xs text-zinc-400 mt-1">{teamModel.getRoleLabel(currentMembership.role)} · {currentMembership.team.memberCount ?? 0} members</p>
              </div>
              <Btn size="sm" variant="outline" onClick={() => onOpenTeam(currentMembership.team.id)}>Manage team</Btn>
            </div>
          ) : (
            <div className="space-y-3">
              <p className="text-sm text-zinc-400">You do not have an active team yet. Join an existing team or create a new one to get started.</p>
              <div className="flex gap-2">
                <Btn size="sm" variant="outline" onClick={onJoinTeam}>Join team</Btn>
                <Btn size="sm" onClick={onCreateTeam}>Create team</Btn>
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h3 className="font-bold text-white">Your teams</h3>
            <p className="text-sm text-zinc-400">Manage a team from here, while Profile remains the place to change the active team context.</p>
          </div>
          <Badge color="blue">{memberships.length}</Badge>
        </div>

        {!memberships.length && (
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 text-sm text-zinc-400">
            You do not currently belong to any teams yet.
          </div>
        )}

        {memberships.map(membership => {
          const isCurrent = membership.team.id === currentTeamId
          return (
            <div key={membership.team.id} className={`bg-zinc-900 border rounded-2xl p-4 ${isCurrent ? 'border-amber-500/60' : 'border-zinc-800'}`}>
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <h3 className="font-bold text-white">{membership.team.name}</h3>
                    {isCurrent && <Badge color="amber">Current</Badge>}
                  </div>
                  <div className="mt-2 flex flex-wrap gap-2">
                    <Badge color="blue">{teamModel.getRoleLabel(membership.role)}</Badge>
                    <Badge color="gray">{membership.team.memberCount ?? 0} members</Badge>
                  </div>
                  <p className="text-xs text-zinc-500 mt-2">Joined {new Date(membership.joinedAt).toLocaleDateString('en-GB')}</p>
                </div>
              </div>
              <div className="mt-4">
                <Btn className="w-full" onClick={() => onOpenTeam(membership.team.id)}>{isCurrent ? 'Manage current team' : 'Open team management'}</Btn>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}


function normaliseEmail(email) {
  return email?.trim().toLowerCase() ?? ""
}

function JoinTeamPage({ onJoinTeam, onCreateTeam, saving }) {
  const [joinCode, setJoinCode] = useState('')
  const [status, setStatus] = useState({ error: '', success: '', teamName: '' })

  const submit = async event => {
    event.preventDefault()
    setStatus({ error: '', success: '', teamName: '' })
    try {
      const result = await onJoinTeam(joinCode)
      setStatus({ error: '', success: result.message, teamName: result.team.name })
      setJoinCode('')
    } catch (err) {
      setStatus({ error: err?.message ?? 'Failed to join team.', success: '', teamName: '' })
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="font-display text-2xl font-bold text-white">Join Team</h2>
          <p className="text-sm text-zinc-400">Enter a team join code to join immediately as a Player.</p>
        </div>
        <Btn size="sm" variant="outline" onClick={onCreateTeam}>Create team</Btn>
      </div>
      <form onSubmit={submit} className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <Input label="Team join code" value={joinCode} onChange={event => setJoinCode(event.target.value.toUpperCase())} placeholder="AB12CD34" maxLength={16} />
        {status.error && <p className="mb-3 text-sm text-red-400">{status.error}</p>}
        {status.success && (
          <div className="mb-3 rounded-xl border border-emerald-800/60 bg-emerald-950/40 px-3 py-3">
            <p className="text-sm text-emerald-300">{status.success}</p>
            {status.teamName && <p className="text-xs text-emerald-200/80 mt-1">Team: {status.teamName}</p>}
          </div>
        )}
        <Btn type="submit" disabled={saving || !joinCode.trim()}>{saving ? 'Joining...' : 'Join team'}</Btn>
      </form>
    </div>
  )
}

function PlayerProfilePage({ profile, currentUser, players, memberships, currentTeamId, onSwitchTeam, onSaveProfile, onCreateTeam, onJoinTeam, onSignOut, saving }) {
  const [displayName, setDisplayName] = useState(profile?.displayName ?? '')
  const [preferredAuthMethod, setPreferredAuthMethod] = useState(profile?.preferredAuthMethod ?? 'email')
  const [linkedPlayerId, setLinkedPlayerId] = useState(profile?.playerId ?? '')
  const [receiveTeamNotifications, setReceiveTeamNotifications] = useState(Boolean(profile?.receiveTeamNotifications))
  const [status, setStatus] = useState({ error: '', success: '' })

  useEffect(() => {
    setDisplayName(profile?.displayName ?? '')
    setPreferredAuthMethod(profile?.preferredAuthMethod ?? 'email')
    setLinkedPlayerId(profile?.playerId ?? '')
    setReceiveTeamNotifications(Boolean(profile?.receiveTeamNotifications))
  }, [profile?.displayName, profile?.preferredAuthMethod, profile?.playerId, profile?.receiveTeamNotifications])

  const submit = async event => {
    event.preventDefault()
    setStatus({ error: '', success: '' })

    if (preferredAuthMethod === 'email' && !profile?.email) {
      setStatus({ error: 'Your account has no email. Use WhatsApp as default, or add email in Supabase Auth.', success: '' })
      return
    }
    if (preferredAuthMethod === 'whatsapp' && !profile?.mobile) {
      setStatus({ error: 'Your account has no mobile number. Use Email as default, or add mobile in Supabase Auth.', success: '' })
      return
    }

    try {
      await onSaveProfile({
        displayName: displayName.trim(),
        preferredAuthMethod,
        playerId: linkedPlayerId || profile?.playerId || null,
        receiveTeamNotifications,
      })
      setStatus({ error: '', success: 'Profile updated.' })
    } catch (err) {
      setStatus({ error: err?.message ?? 'Failed to save profile.', success: '' })
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="font-display text-2xl font-bold text-white">Profile</h2>
          <p className="text-sm text-zinc-400">Manage personal account settings for the signed-in user.</p>
        </div>
        <div className="flex gap-2">
          <Btn size="sm" variant="outline" onClick={onJoinTeam}>Join team</Btn>
          <Btn size="sm" onClick={onCreateTeam}>Create team</Btn>
        </div>
      </div>

      <form onSubmit={submit} className="space-y-4">
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <h3 className="font-bold text-white mb-3">Personal details</h3>
          <Input label="Display name" value={displayName} onChange={event => setDisplayName(event.target.value)} placeholder="How your name should appear" />
          <p className="text-xs text-zinc-400 mb-3">Signed in as <span className="text-zinc-200">{currentUser?.email || currentUser?.phone || currentUser?.id}</span></p>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-1">Email</label>
              <div className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-3 py-2.5 text-sm text-zinc-300">{profile?.email || 'No email on account'}</div>
            </div>
            <div>
              <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-1">Mobile</label>
              <div className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-3 py-2.5 text-sm text-zinc-300">{profile?.mobile || 'No mobile on account'}</div>
            </div>
          </div>
        </div>

        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <h3 className="font-bold text-white mb-3">Preferences</h3>
          <Sel label="Preferred authentication method" value={preferredAuthMethod} onChange={event => setPreferredAuthMethod(event.target.value)}>
            <option value="email">Email OTP</option>
            <option value="whatsapp">WhatsApp OTP</option>
          </Sel>
          <Sel label="Linked player (optional)" value={linkedPlayerId} onChange={event => setLinkedPlayerId(event.target.value)}>
            <option value="">No linked player</option>
            {players.map(player => <option key={player.id} value={player.id}>{player.name}</option>)}
          </Sel>
          <label className="flex items-center justify-between gap-3 rounded-xl border border-zinc-700 bg-zinc-800 px-3 py-3">
            <div>
              <p className="text-sm font-medium text-white">Receive team notifications</p>
              <p className="text-xs text-zinc-400">Use this preference for team-level reminders and updates later.</p>
            </div>
            <input type="checkbox" checked={receiveTeamNotifications} onChange={event => setReceiveTeamNotifications(event.target.checked)} className="h-4 w-4" />
          </label>
          {status.error && <p className="mt-3 text-sm text-red-400">{status.error}</p>}
          {status.success && <p className="mt-3 text-sm text-emerald-400">{status.success}</p>}
          <div className="mt-4 flex flex-col gap-2 sm:flex-row">
            <Btn type="submit" disabled={saving} className="sm:flex-1">{saving ? 'Saving...' : 'Save profile'}</Btn>
            <Btn type="button" variant="ghost" onClick={onSignOut} className="sm:flex-1">Sign out</Btn>
          </div>
        </div>
      </form>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h3 className="font-bold text-white">Current team context</h3>
            <p className="text-xs text-zinc-400">Profile is now the single place to view and change the active team used throughout the app.</p>
          </div>
          <Badge color={memberships.length ? 'amber' : 'gray'}>{memberships.length ? 'Switcher available' : 'No teams'}</Badge>
        </div>
        <TeamSwitcher memberships={memberships} currentTeamId={currentTeamId} onSwitchTeam={onSwitchTeam} />
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h3 className="font-bold text-white">Team memberships</h3>
            <p className="text-xs text-zinc-400">Your current active memberships across teams.</p>
          </div>
          <Badge color="blue">{memberships.length}</Badge>
        </div>
        <div className="space-y-2">
          {memberships.length === 0 ? (
            <p className="text-sm text-zinc-400">You are not on a team yet. Create one to get started.</p>
          ) : memberships.map(membership => (
            <div key={membership.team.id} className="rounded-xl border border-zinc-800 bg-zinc-800/80 px-3 py-3">
              <div className="flex items-center justify-between gap-2">
                <div>
                  <p className="text-sm font-medium text-white">{membership.team.name}</p>
                  <p className="text-xs text-zinc-500">Join code {membership.team.joinCode || 'N/A'} · {membership.team.memberCount ?? 0} members</p>
                </div>
                <Badge color="amber">{teamModel.getRoleLabel(membership.role)}</Badge>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

function CreateTeamPage({ onCreateTeam, saving }) {
  const [name, setName] = useState('')
  const [error, setError] = useState('')

  const submit = async event => {
    event.preventDefault()
    setError('')
    try {
      await onCreateTeam(name.trim())
    } catch (err) {
      setError(err?.message ?? 'Failed to create team')
    }
  }

  return (
    <div className="space-y-4">
      <div>
        <h2 className="font-display text-2xl font-bold text-white">Create Team</h2>
        <p className="text-sm text-zinc-400">Create a new team and become its captain automatically.</p>
      </div>
      <form onSubmit={submit} className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <Input label="Team name" value={name} onChange={event => setName(event.target.value)} placeholder="White Horse A" />
        {error && <p className="mb-3 text-sm text-red-400">{error}</p>}
        <Btn type="submit" disabled={saving || !name.trim()}>{saving ? 'Creating...' : 'Create team'}</Btn>
      </form>
    </div>
  )
}

export default function App() {
  const [tab, setTab] = useState(0)
  const [isMoreMenuOpen, setIsMoreMenuOpen] = useState(false)
  const [route, setRoute] = useState(() => getRoute())
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState('')
  const [authLoading, setAuthLoading] = useState(true)
  const [session, setSession] = useState(null)
  const [profile, setProfile] = useState(null)
  const [memberContext, setMemberContext] = useState({ profile: null, memberships: [], player: null, platformRole: null, isPlatformAdmin: false })
  const [currentTeamId, setCurrentTeamId] = useState(() => localStorage.getItem(TEAM_STORAGE_KEY) || null)
  const [teamRoster, setTeamRoster] = useState({ members: [], invites: [] })
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

  const loadTeamRoster = useCallback(async (teamId) => {
    if (!teamId) {
      setTeamRoster({ members: [], invites: [] })
      return
    }

    const [membershipRows, inviteRows, playerRows] = await Promise.all([
      teamModel.listTeamMemberships(teamId),
      teamModel.listPendingTeamInvites(teamId),
      db.loadAll({ teamId }).then(data => data.players),
    ])

    const playersById = new Map(playerRows.map(player => [player.id, player]))
    setTeamRoster({
      members: membershipRows
        .filter(row => row.status === 'active')
        .map(row => ({
          id: row.id,
          playerId: row.player_id,
          playerName: playersById.get(row.player_id)?.name ?? 'Unknown player',
          email: playersById.get(row.player_id)?.email ?? '',
          mobile: playersById.get(row.player_id)?.mobile ?? '',
          preferredAuthMethod: playersById.get(row.player_id)?.preferredAuthMethod ?? 'email',
          receiveTeamNotifications: playersById.get(row.player_id)?.receiveTeamNotifications ?? true,
          role: normaliseTeamRole(row.role),
          status: row.status,
        }))
        .sort((a, b) => a.playerName.localeCompare(b.playerName)),
      invites: inviteRows.map(row => ({
        id: row.id,
        email: row.email,
        playerId: row.player_id,
        playerName: playersById.get(row.player_id)?.name ?? '',
        invitedAt: row.created_at,
        invitedByPlayerId: row.invited_by_player_id,
        token: row.token,
        role: TEAM_ROLE.MEMBER,
        status: row.status,
      })),
    })
  }, [])

  useEffect(() => {
    const handleRouteChange = () => setRoute(getRoute())
    window.addEventListener('popstate', handleRouteChange)
    return () => window.removeEventListener('popstate', handleRouteChange)
  }, [])

  useEffect(() => {
    setIsMoreMenuOpen(false)
  }, [route.name, currentTeamId])

  useEffect(() => {
    auth.getSession()
      .then(currentSession => {
        setSession(currentSession)
        if (currentSession?.user) setCurrentPlayer({ id: currentSession.user.id })
      })
      .catch(() => setSession(null))
      .finally(() => setAuthLoading(false))

    const unsubscribe = auth.onAuthStateChange(nextSession => {
      setSession(nextSession)
      setCurrentPlayer(nextSession?.user ? { id: nextSession.user.id } : null)
    })
    return unsubscribe
  }, [])

  const refreshMemberContext = useCallback(async (user = session?.user, nextRoute = route) => {
    if (!user) return
    const context = await resolveAuthenticatedPlayerContext({ user })
    setProfile(context.profile)
    setMemberContext(context)

    const resolvedTeamId = resolveCurrentTeamContext({
      routeTeamId: nextRoute.teamId,
      storedTeamId: localStorage.getItem(TEAM_STORAGE_KEY),
      memberships: context.memberships,
    })
    setCurrentTeamId(resolvedTeamId)

    if (nextRoute.name === 'team' && resolvedTeamId && nextRoute.teamId !== resolvedTeamId) {
      navigate(`/teams/${resolvedTeamId}`, { replace: true })
    }

    return context
  }, [route, session?.user])

  useEffect(() => {
    let cancelled = false

    if (!session?.user) {
      setProfile(null)
      setMemberContext({ profile: null, memberships: [], player: null, platformRole: null, isPlatformAdmin: false })
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
    if (route.name === 'team' && currentTeamId) {
      loadTeamRoster(currentTeamId).catch(err => console.error('Failed to load team roster', err))
    }
  }, [route.name, currentTeamId, loadTeamRoster])

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
      return await fn()
    } catch (err) {
      setSaveError(err?.message ?? 'Failed to save changes')
      console.error('Save failed:', err)
      throw err
    } finally {
      setSaving(false)
    }
  }

  const withProtectedAction = useCallback((action, fn, message) => async (unlockCode) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    await teamModel.assertProtectedActionAccess({
      action,
      membership: currentTeamMembership,
      platformRole: memberContext.platformRole,
      teamId: currentTeamId,
      unlockCode,
      message,
    })
    return fn()
  }), [currentTeamId, currentTeamMembership, memberContext.platformRole])

  const handleSaveProfile = useCallback((updates) => withSave(async () => {
    if (!session?.user?.id) throw new Error('You must be signed in.')
    const updated = await userProfileDb.updateCurrentUserProfile(session.user.id, updates)
    setProfile(updated)
    setMemberContext(context => ({ ...context, profile: updated }))
    if (updated?.playerId) {
      setPlayers(prev => prev.map(player => player.id === updated.playerId ? { ...player, name: updated.displayName, email: updated.email, authUserId: session.user.id } : player))
    }
    return updated
  }), [session?.user?.id])

  const handleCreateTeam = useCallback((teamName) => withSave(async () => {
    if (!session?.user) throw new Error('You must be signed in.')
    if (!teamName?.trim()) throw new Error('Team name is required.')

    const player = await userProfileDb.ensureCurrentUserPlayer({ user: session.user })
    let joinCode = ''
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const candidate = generateJoinCode()
      const existing = await teamModel.getTeamByJoinCode(candidate)
      if (!existing) {
        joinCode = candidate
        break
      }
    }
    if (!joinCode) throw new Error('Could not generate a unique join code. Please try again.')

    const team = await teamModel.createTeam({ name: teamName.trim(), createdBy: player.id, joinCode })
    await teamModel.addTeamMembership({ teamId: team.id, playerId: player.id, role: TEAM_ROLE.CAPTAIN, status: 'active' })
    const context = await refreshMemberContext(session.user, { name: 'team', teamId: team.id })
    setProfile(context?.profile ?? profile)
    navigate(`/teams/${team.id}`)
  }), [refreshMemberContext, session?.user, profile])

  const handleSignOut = async () => {
    try {
      await auth.signOut()
      setSession(null)
      setProfile(null)
      setCurrentPlayer(null)
      setCurrentTeamId(null)
      setMemberContext({ profile: null, memberships: [], player: null, platformRole: null, isPlatformAdmin: false })
      navigate('/', { replace: true })
    } catch (err) {
      console.error('Sign-out failed:', err)
    }
  }

  const handleInvitePlayer = useCallback((payload) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    if (!currentTeamMembership) throw new Error('You are not a member of this team.')
    assertActionAccess({ action: APP_ACTION.MANAGE_TEAM_OPERATIONS, membership: currentTeamMembership, platformRole: memberContext.platformRole, message: 'Only captains and vice-captains can invite players.' })

    const email = normaliseEmail(payload.email)
    const displayName = payload.displayName?.trim()
    if (!displayName) throw new Error('Display name is required.')
    if (!email) throw new Error('Email is required.')

    const notes = []
    let player = await db.findPlayerByEmail(email)
    if (player?.authUserId) notes.push('Existing user matched by email.')
    else if (player) notes.push('Existing player matched by email.')

    if (!player) {
      player = await db.createOrReusePlayerByEmail({ email, displayName })
      notes.push('New player created and invited.')
      setPlayers(prev => [...prev.filter(existing => existing.id !== player.id), player].sort((a, b) => a.name.localeCompare(b.name)))
    }

    const existingMembership = await teamModel.getTeamMembership({ teamId: currentTeamId, playerId: player.id })
    const inviteToken = teamInvites.generateSecureInviteToken()

    if (existingMembership?.status === 'active') {
      await teamModel.upsertPendingTeamInvite({
        teamId: currentTeamId,
        email,
        token: inviteToken,
        playerId: player.id,
        invitedByPlayerId: memberContext.player?.id ?? null,
        expiresAt: null,
      })
      notes.unshift('Already on team.')
      await loadTeamRoster(currentTeamId)
      return {
        message: `${player.name} is already an active member of ${currentTeamMembership.team.name}.`,
        notes,
      }
    }

    await teamModel.addTeamMembership({
      teamId: currentTeamId,
      playerId: player.id,
      role: normaliseTeamRole(existingMembership?.role) || TEAM_ROLE.MEMBER,
      status: 'active',
    })

    await teamModel.upsertPendingTeamInvite({
      teamId: currentTeamId,
      email,
      token: inviteToken,
      playerId: player.id,
      invitedByPlayerId: memberContext.player?.id ?? null,
      expiresAt: null,
    })

    const emailResult = await teamInvites.sendTeamInviteEmail({
      email,
      teamName: currentTeamMembership.team.name,
      inviteToken,
      invitedPlayerName: player.name,
    })
    notes.push(emailResult.message)

    await Promise.all([loadTeamRoster(currentTeamId), refreshMemberContext(session?.user)])

    return {
      message: `${player.name} has been added to ${currentTeamMembership.team.name} and invite tracking is up to date.`,
      notes,
    }
  }), [currentTeamId, currentTeamMembership, loadTeamRoster, memberContext.player?.id, refreshMemberContext, session?.user])


  const handleJoinTeam = useCallback((joinCode) => withSave(async () => {
    if (!session?.user) throw new Error('You must be signed in.')
    const normalizedJoinCode = joinCode?.trim().toUpperCase()
    if (!normalizedJoinCode) throw new Error('Enter a team join code.')

    const player = await userProfileDb.ensureCurrentUserPlayer({ user: session.user })
    const team = await teamModel.getTeamByJoinCode(normalizedJoinCode)
    if (!team) throw new Error('That join code is invalid. Check the code and try again.')

    const existingMembership = await teamModel.getTeamMembership({ teamId: team.id, playerId: player.id })
    if (existingMembership?.status === 'active') {
      await teamModel.acceptTeamInvite({ teamId: team.id, email: player.email, playerId: player.id })
      await refreshMemberContext(session.user, { name: 'team', teamId: team.id })
      await loadTeamRoster(team.id)
      return {
        team,
        message: `You already belong to ${team.name}. Nothing changed.`,
      }
    }

    await teamModel.addTeamMembership({ teamId: team.id, playerId: player.id, role: TEAM_ROLE.MEMBER, status: 'active' })
    if (player.email) {
      await teamModel.acceptTeamInvite({ teamId: team.id, email: player.email, playerId: player.id })
    }
    await refreshMemberContext(session.user, { name: 'team', teamId: team.id })
    await loadTeamRoster(team.id)
    navigate(`/teams/${team.id}`)

    return {
      team,
      message: `You joined ${team.name} successfully.`,
    }
  }), [loadTeamRoster, refreshMemberContext, session?.user])

  const handleUpdateMemberRole = useCallback((member, nextRole) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    assertActionAccess({ action: APP_ACTION.MANAGE_TEAM_ROLES, membership: currentTeamMembership, message: 'Only the captain can change team roles.' })
    if (!member?.id) throw new Error('Member is required.')
    if (!canAssignTeamRole({ actorMembership: currentTeamMembership, targetRole: nextRole }) && nextRole !== TEAM_ROLE.CAPTAIN) throw new Error('Invalid role.')

    if (member.playerId === currentTeamMembership.playerId && nextRole !== TEAM_ROLE.CAPTAIN) {
      throw new Error('Captain cannot remove their own captaincy without transferring it first.')
    }
    if (nextRole === TEAM_ROLE.CAPTAIN) {
      const currentCaptain = teamRoster.members.find(entry => entry.playerId === currentTeamMembership.playerId)
      await teamModel.transferCaptaincy({
        teamId: currentTeamId,
        actorMembership: currentTeamMembership,
        incomingCaptainMembershipId: member.id,
        outgoingCaptainMembershipId: currentCaptain?.id ?? null,
        incomingCaptainPlayerId: member.playerId,
      })
    } else {
      if (member.role === TEAM_ROLE.CAPTAIN) throw new Error('Transfer captaincy instead of demoting the captain directly.')
      await teamModel.changeTeamMemberRole({ membershipId: member.id, nextRole, actorMembership: currentTeamMembership, teamId: currentTeamId, targetPlayerId: member.playerId, previousRole: member.role })
    }

    await Promise.all([loadTeamRoster(currentTeamId), refreshMemberContext(session?.user)])
  }), [currentTeamId, currentTeamMembership, loadTeamRoster, refreshMemberContext, session?.user, teamRoster.members])

  const handleSavePlayerDetails = useCallback((payload) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    if (!currentTeamMembership) throw new Error('You are not a member of this team.')
    if (!payload?.playerId || !payload?.membershipId) throw new Error('Player details are required.')
    const canEditPlayer = canEditPlayerProfileInTeam({ actorMembership: currentTeamMembership, targetPlayerId: payload.playerId, actorPlayerId: currentTeamMembership.playerId, platformRole: memberContext.platformRole })
    if (!canEditPlayer) throw new Error('You do not have permission to edit this player.')

    const currentPlayer = players.find(player => player.id === payload.playerId)
    if (!currentPlayer) throw new Error('Player not found.')

    const displayName = payload.displayName?.trim()
    const email = payload.email?.trim().toLowerCase()
    const mobile = payload.mobile?.trim() ?? ''
    if (!displayName) throw new Error('Display name is required.')
    if (!email) throw new Error('Email is required.')

    await db.updatePlayer({
      ...currentPlayer,
      name: displayName,
      email,
      mobile,
    })

    if (payload.role && payload.role !== payload.currentRole) {
      assertActionAccess({ action: APP_ACTION.MANAGE_TEAM_ROLES, membership: currentTeamMembership, message: 'Only the captain can change team roles.' })
      if (!canAssignTeamRole({ actorMembership: currentTeamMembership, targetRole: payload.role }) && payload.role !== TEAM_ROLE.CAPTAIN) throw new Error('Invalid role.')
      const member = teamRoster.members.find(entry => entry.id === payload.membershipId)
      if (!member) throw new Error('Membership not found.')
      if (payload.role === TEAM_ROLE.CAPTAIN) {
        const currentCaptain = teamRoster.members.find(entry => entry.playerId === currentTeamMembership.playerId)
        await teamModel.transferCaptaincy({
          teamId: currentTeamId,
          actorMembership: currentTeamMembership,
          incomingCaptainMembershipId: member.id,
          outgoingCaptainMembershipId: currentCaptain?.id ?? null,
          incomingCaptainPlayerId: member.playerId,
        })
      } else {
        if (member.role === TEAM_ROLE.CAPTAIN) throw new Error('Transfer captaincy instead of demoting the captain directly.')
        if (member.playerId === currentTeamMembership.playerId) {
          throw new Error('Captain cannot remove their own captaincy without transferring it first.')
        }
        await teamModel.changeTeamMemberRole({ membershipId: member.id, nextRole: payload.role, actorMembership: currentTeamMembership, teamId: currentTeamId, targetPlayerId: member.playerId, previousRole: member.role })
      }
    }

    await Promise.all([load(currentTeamId), loadTeamRoster(currentTeamId), refreshMemberContext(session?.user)])
  }), [currentTeamId, currentTeamMembership, load, loadTeamRoster, players, refreshMemberContext, session?.user, teamRoster.members])

  const handleRemoveMember = useCallback((member, unlockCode) => withProtectedAction(APP_ACTION.REMOVE_TEAM_MEMBER, async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    if (!currentTeamMembership) throw new Error('You are not a member of this team.')
    assertActionAccess({ action: APP_ACTION.MANAGE_TEAM_OPERATIONS, membership: currentTeamMembership, platformRole: memberContext.platformRole, message: 'Only captains and vice-captains can remove players.' })
    if (!member?.id) throw new Error('Member is required.')
    if (member.role === TEAM_ROLE.CAPTAIN) throw new Error('Transfer captaincy before removing the captain.')
    if (member.playerId === currentTeamMembership.playerId) throw new Error('You cannot remove yourself from the team here.')

    await teamModel.removeTeamMember({ membershipId: member.id, actorMembership: currentTeamMembership, teamId: currentTeamId, targetPlayerId: member.playerId, previousRole: member.role })
    await Promise.all([load(currentTeamId), loadTeamRoster(currentTeamId), refreshMemberContext(session?.user)])
  }, 'Unlock code verification is required to remove team members.'), [currentTeamId, currentTeamMembership, load, loadTeamRoster, refreshMemberContext, session?.user, withProtectedAction])

  const handleRevokeInvite = useCallback((invite) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    if (!currentTeamMembership) throw new Error('You are not a member of this team.')
    assertActionAccess({ action: APP_ACTION.MANAGE_TEAM_OPERATIONS, membership: currentTeamMembership, platformRole: memberContext.platformRole, message: 'Only captains and vice-captains can revoke invites.' })
    if (!invite?.id) throw new Error('Invite is required.')

    await teamModel.updateTeamInvite({ inviteId: invite.id, status: 'cancelled' })
    await loadTeamRoster(currentTeamId)
  }), [currentTeamId, currentTeamMembership, loadTeamRoster])

  const handleResendInvite = useCallback((invite) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    if (!currentTeamMembership) throw new Error('You are not a member of this team.')
    assertActionAccess({ action: APP_ACTION.MANAGE_TEAM_OPERATIONS, membership: currentTeamMembership, platformRole: memberContext.platformRole, message: 'Only captains and vice-captains can resend invites.' })
    if (!invite?.id || !invite?.email) throw new Error('Invite is required.')

    const inviteToken = teamInvites.generateSecureInviteToken()
    await teamModel.updateTeamInvite({
      inviteId: invite.id,
      token: inviteToken,
      playerId: invite.playerId,
      invitedByPlayerId: memberContext.player?.id ?? null,
      expiresAt: null,
    })

    const invitedPlayerName = invite.playerName || invite.email
    const emailResult = await teamInvites.sendTeamInviteEmail({
      email: invite.email,
      teamName: currentTeamMembership.team.name,
      inviteToken,
      invitedPlayerName,
    })

    await loadTeamRoster(currentTeamId)

    return { message: emailResult.message }
  }), [currentTeamId, currentTeamMembership, loadTeamRoster, memberContext.player?.id])

  const handleAddFineType = useCallback((payload) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    assertActionAccess({ action: APP_ACTION.MANAGE_FINE_TYPES, membership: currentTeamMembership, platformRole: memberContext.platformRole, message: 'Only captains and vice-captains can manage fine types.' })
    if (!payload?.name?.trim()) throw new Error('Fine name is required.')
    const cost = Number(payload.cost)
    if (Number.isNaN(cost) || cost < 0) throw new Error('Enter a valid fine cost.')

    const created = await db.addFineType({ id: uuid(), name: payload.name.trim(), cost, teamId: currentTeamId })
    setFineTypes(prev => [...prev, created].sort((a, b) => a.cost - b.cost || a.name.localeCompare(b.name)))
    return created
  }), [currentTeamId, currentTeamMembership?.role])

  const handleUpdateFineType = useCallback((payload) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    assertActionAccess({ action: APP_ACTION.MANAGE_FINE_TYPES, membership: currentTeamMembership, platformRole: memberContext.platformRole, message: 'Only captains and vice-captains can manage fine types.' })
    if (!payload?.name?.trim()) throw new Error('Fine name is required.')
    const cost = Number(payload.cost)
    if (Number.isNaN(cost) || cost < 0) throw new Error('Enter a valid fine cost.')

    const updated = await db.updateFineType({ ...payload, name: payload.name.trim(), cost, teamId: currentTeamId })
    setFineTypes(prev => prev.map(item => item.id === updated.id ? updated : item).sort((a, b) => a.cost - b.cost || a.name.localeCompare(b.name)))
    return updated
  }), [currentTeamId, currentTeamMembership?.role])

  const handleDeleteFineType = useCallback((fineType, unlockCode) => withProtectedAction(APP_ACTION.DELETE_FINE_TYPE, async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    assertActionAccess({ action: APP_ACTION.MANAGE_FINE_TYPES, membership: currentTeamMembership, platformRole: memberContext.platformRole, message: 'Only captains and vice-captains can manage fine types.' })
    await db.deleteFineTypeWithAudit({ id: fineType.id, teamId: currentTeamId, actorMembership: currentTeamMembership, platformRole: memberContext.platformRole, fineTypeName: fineType.name })
    setFineTypes(prev => prev.filter(item => item.id !== fineType.id))
  }, 'Unlock code verification is required to delete fine types.'), [currentTeamId, currentTeamMembership?.role, withProtectedAction])

  const handleAddSeason = useCallback((payload) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    assertActionAccess({ action: APP_ACTION.MANAGE_SEASONS, membership: currentTeamMembership, platformRole: memberContext.platformRole, message: 'Only captains and vice-captains can manage seasons.' })
    if (!payload?.name?.trim()) throw new Error('Season name is required.')

    const created = await db.addSeason({ id: uuid(), name: payload.name.trim(), type: payload.type || 'League', teamId: currentTeamId })
    setSeasons(prev => [...prev, created].sort((a, b) => a.name.localeCompare(b.name)))
    return created
  }), [currentTeamId, currentTeamMembership?.role])

  const handleUpdateSeason = useCallback((payload) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    assertActionAccess({ action: APP_ACTION.MANAGE_SEASONS, membership: currentTeamMembership, platformRole: memberContext.platformRole, message: 'Only captains and vice-captains can manage seasons.' })
    if (!payload?.name?.trim()) throw new Error('Season name is required.')

    const updated = await db.updateSeason({ ...payload, name: payload.name.trim(), type: payload.type || 'League', teamId: currentTeamId })
    setSeasons(prev => prev.map(item => item.id === updated.id ? updated : item).sort((a, b) => a.name.localeCompare(b.name)))
    return updated
  }), [currentTeamId, currentTeamMembership?.role])

  const handleDeleteSeason = useCallback((season, unlockCode) => withProtectedAction(APP_ACTION.DELETE_SEASON, async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    assertActionAccess({ action: APP_ACTION.MANAGE_SEASONS, membership: currentTeamMembership, platformRole: memberContext.platformRole, message: 'Only captains and vice-captains can manage seasons.' })
    await db.deleteSeasonWithAudit({ id: season.id, teamId: currentTeamId, actorMembership: currentTeamMembership, platformRole: memberContext.platformRole, seasonName: season.name })
    setSeasons(prev => prev.filter(item => item.id !== season.id))
  }, 'Unlock code verification is required to delete seasons.'), [currentTeamId, currentTeamMembership?.role, withProtectedAction])

  const getCaptainContacts = useCallback(() => teamRoster.members
    .filter(member => member.role === TEAM_ROLE.CAPTAIN)
    .map(member => ({
      playerName: member.playerName,
      email: member.email,
      receiveTeamNotifications: member.receiveTeamNotifications,
    })), [teamRoster.members])

  const handleSetUnlockCode = useCallback((unlockCode) => withSave(async () => {
    if (!currentTeamId || !currentTeamMembership) throw new Error('Select a team first.')
    await teamModel.setTeamUnlockCode({ teamId: currentTeamId, unlockCode, actorMembership: currentTeamMembership })
    await refreshMemberContext(session?.user)
  }), [currentTeamId, currentTeamMembership, refreshMemberContext, session?.user])

  const handleChangeUnlockCode = useCallback((currentUnlockCode, nextUnlockCode) => withSave(async () => {
    if (!currentTeamId || !currentTeamMembership) throw new Error('Select a team first.')
    await teamModel.changeTeamUnlockCode({ teamId: currentTeamId, currentUnlockCode, nextUnlockCode, actorMembership: currentTeamMembership })
    await refreshMemberContext(session?.user)
  }), [currentTeamId, currentTeamMembership, refreshMemberContext, session?.user])

  const handleRequestUnlockCodeReset = useCallback((payload) => withSave(async () => {
    if (!currentTeamId || !currentTeamMembership) throw new Error('Select a team first.')
    await teamModel.requestCaptainUnlockCodeReset({
      teamId: currentTeamId,
      actorMembership: currentTeamMembership,
      verificationMethod: payload.verificationMethod,
      verificationTarget: payload.verificationTarget,
      otpToken: payload.otpToken,
      captainContacts: getCaptainContacts(),
      teamName: currentTeamMembership.team.name,
    })
    await refreshMemberContext(session?.user)
  }), [currentTeamId, currentTeamMembership, getCaptainContacts, refreshMemberContext, session?.user])

  const handleAdminUnlockCodeReset = useCallback(() => withSave(async () => {
    if (!currentTeamId || !currentTeamMembership) throw new Error('Select a team first.')
    await teamModel.triggerAdminUnlockCodeReset({
      teamId: currentTeamId,
      platformRole: memberContext.platformRole,
      actorMembership: currentTeamMembership,
      captainContacts: getCaptainContacts(),
      teamName: currentTeamMembership.team.name,
    })
    await refreshMemberContext(session?.user)
  }), [currentTeamId, currentTeamMembership, getCaptainContacts, memberContext.platformRole, refreshMemberContext, session?.user])

  const isInMoreSection = isMoreRoute(route.name)
  const showBottomNav = !!currentTeamId && (route.name === 'app' || isInMoreSection)

  const openPrimaryTab = (nextTab) => {
    setTab(nextTab)
    setIsMoreMenuOpen(false)
    if (route.name !== 'app') navigate('/')
  }

  const navItems = [
    { label: 'Dashboard', icon: '📊', onClick: () => openPrimaryTab(0), isActive: route.name === 'app' && tab === 0 && !isMoreMenuOpen },
    { label: 'Matches', icon: '🎱', onClick: () => openPrimaryTab(1), isActive: route.name === 'app' && tab === 1 && !isMoreMenuOpen },
    { label: 'Fines', icon: '💰', onClick: () => openPrimaryTab(2), isActive: route.name === 'app' && tab === 2 && !isMoreMenuOpen },
    { label: 'More', icon: '➕', onClick: () => setIsMoreMenuOpen(open => !open), isActive: isInMoreSection || isMoreMenuOpen },
  ]

  if (authLoading) return <Spinner />

  return (
    <div className="min-h-screen bg-zinc-950 text-white pb-24">
      <div className="bg-zinc-950/95 border-b border-zinc-800">
        {showBanner && (
          <div className="max-w-lg mx-auto">
            <img
              src={APP_BANNER_PATHS[bannerPathIndex]}
              alt="Roo Bin banner"
              className="h-28 sm:h-36 w-full bg-zinc-950 object-contain object-center"
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
        <div className="max-w-lg mx-auto px-4 pb-2.5 flex items-center justify-between gap-3">
          <div className="inline-flex items-center gap-2 text-[11px] text-zinc-300 bg-zinc-900/80 border border-zinc-700 rounded-md px-2.5 py-1">
            <span className="text-amber-400">🕒</span>
            <span>Last updated: {formatLastUpdated(LAST_UPDATED)}</span>
          </div>
          {currentPlayer && (
            <div className="text-xs text-zinc-500">
              {profile?.displayName || currentPlayer.name}
            </div>
          )}
        </div>
      </div>

      {!currentPlayer ? (
        <AuthGate players={players} setPlayers={setPlayers} onAuthenticated={setCurrentPlayer} />
      ) : (
        <>
          <div className="max-w-lg mx-auto px-4 pt-3">
            {!!saveError && <div className="mb-3 text-sm text-red-400 bg-red-950/40 border border-red-800/50 rounded-xl px-3 py-2">{saveError}</div>}
            {route.name !== 'profile' && currentTeamMembership ? (
              <div className="mb-3 flex items-center justify-between gap-3 rounded-xl border border-zinc-800 bg-zinc-900/60 px-3 py-2.5">
                <div className="min-w-0">
                  <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-zinc-500">Current team</p>
                  <p className="truncate text-sm font-medium text-white">{currentTeamMembership.team.name}</p>
                </div>
                <Badge color="amber">{teamModel.getRoleLabel(currentTeamMembership.role)}</Badge>
              </div>
            ) : null}

            {route.name === 'profile' ? (
              <PlayerProfilePage
                profile={profile}
                currentUser={session?.user}
                players={players}
                memberships={memberContext.memberships}
                currentTeamId={currentTeamId}
                onSwitchTeam={teamId => switchTeam(teamId, 'app')}
                onSaveProfile={handleSaveProfile}
                onCreateTeam={() => navigate('/teams/new')}
                onJoinTeam={() => navigate('/teams/join')}
                onSignOut={handleSignOut}
                saving={saving}
              />
            ) : route.name === 'create-team' ? (
              <CreateTeamPage onCreateTeam={handleCreateTeam} saving={saving} />
            ) : route.name === 'join-team' ? (
              <JoinTeamPage onJoinTeam={handleJoinTeam} onCreateTeam={() => navigate('/teams/new')} saving={saving} />
            ) : route.name === 'teams' ? (
              <TeamsIndex
                memberships={memberContext.memberships}
                currentTeamId={currentTeamId}
                onOpenTeam={teamId => switchTeam(teamId, 'team')}
                onCreateTeam={() => navigate('/teams/new')}
                onJoinTeam={() => navigate('/teams/join')}
              />
            ) : !currentTeamId ? (
              <div className="space-y-3">
                <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 text-sm text-zinc-400">
                  No current team is available for this account yet.
                </div>
                <div className="flex gap-2">
                  <Btn variant="outline" onClick={() => navigate('/teams')}>View teams</Btn>
                  <Btn variant="outline" onClick={() => navigate('/teams/join')}>Join a team</Btn>
                  <Btn onClick={() => navigate('/teams/new')}>Create your first team</Btn>
                </div>
              </div>
            ) : loading ? <Spinner /> : error ? <ErrorScreen error={error} onRetry={() => load(currentTeamId)} /> : route.name === 'team' ? (
              <TeamManagementPage
                team={currentTeamMembership?.team}
                membership={{ ...currentTeamMembership, email: profile?.email, mobile: profile?.mobile, preferredAuthMethod: profile?.preferredAuthMethod, platformRole: memberContext.platformRole, isPlatformAdmin: memberContext.isPlatformAdmin }}
                members={teamRoster.members}
                invites={teamRoster.invites}
                fineTypes={fineTypes}
                seasons={seasons}
                onOpenApp={() => navigate('/')}
                onBackToTeams={() => navigate('/teams')}
                onRefresh={async () => {
                  await Promise.all([load(currentTeamId), loadTeamRoster(currentTeamId)])
                }}
                onInvitePlayer={handleInvitePlayer}
                onUpdateMemberRole={handleUpdateMemberRole}
                onSavePlayerDetails={handleSavePlayerDetails}
                onRemoveMember={handleRemoveMember}
                onRevokeInvite={handleRevokeInvite}
                onResendInvite={handleResendInvite}
                onAddFineType={handleAddFineType}
                onUpdateFineType={handleUpdateFineType}
                onDeleteFineType={handleDeleteFineType}
                onAddSeason={handleAddSeason}
                onUpdateSeason={handleUpdateSeason}
                onDeleteSeason={handleDeleteSeason}
                onSetUnlockCode={handleSetUnlockCode}
                onChangeUnlockCode={handleChangeUnlockCode}
                onRequestUnlockCodeReset={handleRequestUnlockCodeReset}
                onAdminResetUnlockCode={handleAdminUnlockCodeReset}
                saving={saving}
              />
            ) : (
              <>
                {tab === 0 && <Dashboard players={players} fineTypes={fineTypes} seasons={seasons} matches={matches} currentTeam={currentTeamMembership?.team} />}
                {tab === 1 && <MatchesTab players={players} fineTypes={fineTypes} seasons={seasons} matches={matches} setMatches={setMatches} withSave={withSave} currentTeamId={currentTeamId} membership={currentTeamMembership} platformRole={memberContext.platformRole} />}
                {tab === 2 && <FinesTab players={players} matches={matches} setMatches={setMatches} withSave={withSave} currentTeamId={currentTeamId} membership={currentTeamMembership} platformRole={memberContext.platformRole} />}
                {isMoreMenuOpen && (
                  <SetupTab
                    onOpenProfile={() => { setIsMoreMenuOpen(false); navigate('/profile') }}
                    onOpenTeams={() => { setIsMoreMenuOpen(false); navigate('/teams') }}
                    onClose={() => setIsMoreMenuOpen(false)}
                  />
                )}
              </>
            )}

            {route.name !== 'app' && isMoreMenuOpen && (
              <SetupTab
                onOpenProfile={() => { setIsMoreMenuOpen(false); navigate('/profile') }}
                onOpenTeams={() => { setIsMoreMenuOpen(false); navigate('/teams') }}
                onClose={() => setIsMoreMenuOpen(false)}
              />
            )}
          </div>

          {showBottomNav && (
            <div className="fixed bottom-0 left-0 right-0 z-40 bg-zinc-950/95 backdrop-blur border-t border-zinc-800">
              <div className="max-w-lg mx-auto flex">
                {navItems.map(item => (
                  <button key={item.label} onClick={item.onClick}
                    className={`flex-1 py-3 flex flex-col items-center gap-0.5 transition-all ${item.isActive ? 'text-amber-400' : 'text-zinc-500 hover:text-zinc-300'}`}>
                    <span className="text-lg">{item.icon}</span>
                    <span className="text-xs font-bold">{item.label}</span>
                    {item.isActive && <div className="w-4 h-0.5 bg-amber-400 rounded-full mt-0.5" />}
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
