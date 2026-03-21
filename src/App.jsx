import { useState, useEffect, useCallback, useMemo } from 'react'
import * as db from './lib/db'
import * as auth from './lib/auth'
import * as teamModel from './lib/teamModel'
import * as userProfileDb from './lib/userProfile'
import * as teamInvites from './lib/teamInvites'
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

function TeamSwitcher({ memberships, currentTeamId, onSwitchTeam, onViewTeams, onViewProfile }) {
  if (!memberships.length) return null

  return (
    <div className="bg-zinc-900/80 border border-zinc-800 rounded-xl p-3 mb-4">
      <div className="flex items-center justify-between gap-2 mb-2">
        <div>
          <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">Current team</p>
          <p className="text-sm text-white">Switch context safely without leaving the app.</p>
        </div>
        <div className="flex gap-2">
          <Btn size="sm" variant="outline" onClick={onViewProfile}>Profile</Btn>
          <Btn size="sm" variant="outline" onClick={onViewTeams}>My Teams</Btn>
        </div>
      </div>
      <select
        value={currentTeamId ?? ''}
        onChange={event => onSwitchTeam(event.target.value)}
        className="w-full bg-zinc-800 border border-zinc-600 rounded-lg px-3 py-2.5 text-white focus:outline-none focus:border-amber-500 text-sm"
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

function TeamsIndex({ memberships, currentTeamId, onSwitchTeam, onOpenTeam, onCreateTeam, onJoinTeam }) {
  return (
    <div className="space-y-3">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="font-display text-2xl font-bold text-white">My Teams</h2>
          <p className="text-sm text-zinc-400">Choose a team to enter, or switch your app-wide team context.</p>
        </div>
        <div className="flex gap-2">
          <Btn size="sm" variant="outline" onClick={onJoinTeam}>Join team</Btn>
          <Btn size="sm" onClick={onCreateTeam}>Create team</Btn>
        </div>
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
                  <Badge color="blue">{teamModel.getRoleLabel(membership.role)}</Badge>
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

function TeamOverview({ team, membership, onOpenApp, onBackToTeams }) {
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
          <p>Member count: <span className="text-white font-medium">{team.memberCount ?? 0}</span></p>
          <p>Your role: <span className="text-white font-medium">{teamModel.getRoleLabel(membership?.role)}</span></p>
        </div>
      </div>
    </div>
  )
}

function normaliseEmail(email) {
  return email?.trim().toLowerCase() ?? ''
}

function canManageTeam(role) {
  return teamModel.canManageTeam(role)
}

function TeamMembersPage({
  team,
  membership,
  members,
  invites,
  onBackToTeams,
  onOpenApp,
  onRefresh,
  onInvitePlayer,
  onUpdateMemberRole,
  saving,
}) {
  const canInvite = teamModel.canManageTeam(membership?.role)
  const canManageRoles = teamModel.canCaptainManageRoles(membership?.role)
  const [form, setForm] = useState({ displayName: '', email: '' })
  const [status, setStatus] = useState({ error: '', success: '', info: [] })

  useEffect(() => {
    setStatus({ error: '', success: '', info: [] })
  }, [team?.id])

  const submit = async event => {
    event.preventDefault()
    setStatus({ error: '', success: '', info: [] })
    try {
      const result = await onInvitePlayer({
        displayName: form.displayName.trim(),
        email: form.email.trim(),
      })
      setStatus({
        error: '',
        success: result.message,
        info: result.notes ?? [],
      })
      setForm({ displayName: '', email: '' })
    } catch (err) {
      setStatus({ error: err?.message ?? 'Failed to invite player.', success: '', info: [] })
    }
  }

  return (
    <div className="space-y-3">
      <div className="flex gap-2">
        <Btn variant="outline" size="sm" onClick={onBackToTeams}>← My Teams</Btn>
        <Btn size="sm" onClick={onOpenApp}>Open app</Btn>
        <Btn variant="outline" size="sm" onClick={onRefresh}>Refresh</Btn>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-2">
          <div>
            <h2 className="font-display text-2xl font-bold text-white">{team?.name || 'Team'}</h2>
            <p className="text-sm text-zinc-400">Manage members and pending invites for this team.</p>
          </div>
          <Badge color={canInvite ? 'amber' : 'gray'}>{teamModel.getRoleLabel(membership?.role)}</Badge>
        </div>
        <div className="grid grid-cols-3 gap-2 text-sm">
          <div className="rounded-xl border border-zinc-800 bg-zinc-800/70 px-3 py-3">
            <p className="text-zinc-400 text-xs uppercase tracking-wider">Active members</p>
            <p className="text-xl font-bold text-white">{members.length}</p>
          </div>
          <div className="rounded-xl border border-zinc-800 bg-zinc-800/70 px-3 py-3">
            <p className="text-zinc-400 text-xs uppercase tracking-wider">Pending invites</p>
            <p className="text-xl font-bold text-white">{invites.length}</p>
          </div>
          <div className="rounded-xl border border-zinc-800 bg-zinc-800/70 px-3 py-3">
            <p className="text-zinc-400 text-xs uppercase tracking-wider">Your access</p>
            <p className="text-xl font-bold text-white">{teamModel.getRoleLabel(membership?.role)}</p>
          </div>
        </div>
      </div>

      <form onSubmit={submit} className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h3 className="font-bold text-white">Invite player by email</h3>
            <p className="text-xs text-zinc-400">Captains and admins can add a player to this team without requiring account signup.</p>
          </div>
          <Badge color={canInvite ? 'green' : 'red'}>{canInvite ? 'Can invite' : 'View only'}</Badge>
        </div>
        <Input label="Display name" value={form.displayName} onChange={event => setForm(current => ({ ...current, displayName: event.target.value }))} placeholder="Player display name" disabled={!canInvite || saving} />
        <Input label="Email" type="email" required value={form.email} onChange={event => setForm(current => ({ ...current, email: event.target.value }))} placeholder="player@example.com" disabled={!canInvite || saving} />
        {!canInvite && <p className="mb-3 text-sm text-zinc-400">Only captains and admins can send invites.</p>}
        {status.error && <p className="mb-3 text-sm text-red-400">{status.error}</p>}
        {status.success && <p className="mb-2 text-sm text-emerald-400">{status.success}</p>}
        {!!status.info.length && (
          <ul className="mb-3 space-y-1 text-xs text-zinc-400">
            {status.info.map(note => <li key={note}>• {note}</li>)}
          </ul>
        )}
        <Btn type="submit" disabled={!canInvite || saving || !form.displayName.trim() || !form.email.trim()}>
          {saving ? 'Inviting...' : 'Invite player'}
        </Btn>
      </form>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h3 className="font-bold text-white">Active members</h3>
            <p className="text-xs text-zinc-400">Current team roster with role visibility.</p>
          </div>
          <Badge color="blue">{members.length}</Badge>
        </div>
        <div className="space-y-2">
          {!members.length ? (
            <p className="text-sm text-zinc-400">No active members yet.</p>
          ) : members.map(member => {
            const isSelf = member.playerId === membership?.playerId
            const roleOptions = [
              { value: 'admin', label: 'Promote to Vice-captain' },
              { value: 'member', label: 'Demote to Player' },
              { value: 'captain', label: 'Transfer Captaincy' },
            ].filter(option => {
              if (!canManageRoles) return false
              if (member.role === option.value) return false
              if (member.role === 'captain' && option.value !== 'captain') return false
              if (isSelf && option.value !== 'captain') return false
              return true
            })

            return (
              <div key={member.id} className="rounded-xl border border-zinc-800 bg-zinc-800/80 px-3 py-3 flex items-center justify-between gap-3">
                <div>
                  <p className="text-sm font-medium text-white">{member.playerName || 'Unknown player'}{isSelf ? ' (You)' : ''}</p>
                  <p className="text-xs text-zinc-500">{member.email || 'No email saved'}</p>
                </div>
                <div className="flex items-center gap-2">
                  <Badge color="amber">{teamModel.getRoleLabel(member.role)}</Badge>
                  {!!roleOptions.length && (
                    <select
                      className="bg-zinc-900 border border-zinc-700 rounded-lg px-2 py-1.5 text-xs text-white"
                      defaultValue=""
                      disabled={saving}
                      onChange={async event => {
                        const nextRole = event.target.value
                        event.target.value = ''
                        if (!nextRole) return
                        await onUpdateMemberRole(member, nextRole)
                      }}
                    >
                      <option value="">Role actions</option>
                      {roleOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                    </select>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h3 className="font-bold text-white">Pending invites</h3>
            <p className="text-xs text-zinc-400">Outstanding email invites awaiting acceptance or future wiring.</p>
          </div>
          <Badge color="blue">{invites.length}</Badge>
        </div>
        <div className="space-y-2">
          {!invites.length ? (
            <p className="text-sm text-zinc-400">No pending invites.</p>
          ) : invites.map(invite => (
            <div key={invite.id} className="rounded-xl border border-zinc-800 bg-zinc-800/80 px-3 py-3 flex items-center justify-between gap-3">
              <div>
                <p className="text-sm font-medium text-white">{invite.playerName || invite.email}</p>
                <p className="text-xs text-zinc-500">{normaliseEmail(invite.email)}{invite.invitedAt ? ` · invited ${new Date(invite.invitedAt).toLocaleDateString('en-GB')}` : ''}</p>
              </div>
              <div className="flex items-center gap-2">
                <Badge color="gray">{teamModel.getRoleLabel(invite.role)}</Badge>
                <Badge color="blue">pending</Badge>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
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

function PlayerProfilePage({ profile, memberships, onSaveProfile, onCreateTeam, onJoinTeam, saving }) {
  const [displayName, setDisplayName] = useState(profile?.displayName ?? '')
  const [receiveTeamNotifications, setReceiveTeamNotifications] = useState(Boolean(profile?.receiveTeamNotifications))
  const [status, setStatus] = useState({ error: '', success: '' })

  useEffect(() => {
    setDisplayName(profile?.displayName ?? '')
    setReceiveTeamNotifications(Boolean(profile?.receiveTeamNotifications))
  }, [profile?.displayName, profile?.receiveTeamNotifications])

  const submit = async event => {
    event.preventDefault()
    setStatus({ error: '', success: '' })
    try {
      await onSaveProfile({ displayName: displayName.trim(), receiveTeamNotifications })
      setStatus({ error: '', success: 'Profile updated.' })
    } catch (err) {
      setStatus({ error: err?.message ?? 'Failed to save profile.', success: '' })
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="font-display text-2xl font-bold text-white">Player Profile</h2>
          <p className="text-sm text-zinc-400">Manage the player record linked to your signed-in account.</p>
        </div>
        <div className="flex gap-2">
          <Btn size="sm" variant="outline" onClick={onJoinTeam}>Join team</Btn>
          <Btn size="sm" onClick={onCreateTeam}>Create team</Btn>
        </div>
      </div>

      <form onSubmit={submit} className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <Input label="Display name" value={displayName} onChange={event => setDisplayName(event.target.value)} placeholder="How your name should appear" />
        <div className="mb-3">
          <label className="block text-xs font-bold text-zinc-400 uppercase tracking-wider mb-1">Email</label>
          <div className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-3 py-2.5 text-sm text-zinc-300">{profile?.email || 'No email on account'}</div>
        </div>
        <label className="flex items-center justify-between gap-3 rounded-xl border border-zinc-700 bg-zinc-800 px-3 py-3 mb-3">
          <div>
            <p className="text-sm font-medium text-white">Receive team notifications</p>
            <p className="text-xs text-zinc-400">Use this preference for team-level reminders and updates later.</p>
          </div>
          <input type="checkbox" checked={receiveTeamNotifications} onChange={event => setReceiveTeamNotifications(event.target.checked)} className="h-4 w-4" />
        </label>
        {status.error && <p className="mb-3 text-sm text-red-400">{status.error}</p>}
        {status.success && <p className="mb-3 text-sm text-emerald-400">{status.success}</p>}
        <Btn type="submit" disabled={saving}>{saving ? 'Saving...' : 'Save profile'}</Btn>
      </form>

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
          role: row.role,
          status: row.status,
        }))
        .sort((a, b) => a.playerName.localeCompare(b.playerName)),
      invites: inviteRows.map(row => ({
        id: row.id,
        email: row.email,
        playerId: row.player_id,
        playerName: playersById.get(row.player_id)?.name ?? '',
        invitedAt: row.created_at,
        role: 'member',
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

  const handleSaveProfile = useCallback((updates) => withSave(async () => {
    if (!session?.user?.id) throw new Error('You must be signed in.')
    const updated = await userProfileDb.updateCurrentUserProfile(session.user.id, updates)
    setProfile(updated)
    setMemberContext(context => ({ ...context, profile: updated }))
    setPlayers(prev => prev.map(player => player.id === updated.playerId ? { ...player, name: updated.displayName, email: updated.email, authUserId: session.user.id } : player))
    return updated
  }), [session?.user?.id, players])

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
    await teamModel.addTeamMembership({ teamId: team.id, playerId: player.id, role: 'captain', status: 'active' })
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
      setMemberContext({ profile: null, memberships: [], player: null })
      navigate('/', { replace: true })
    } catch (err) {
      console.error('Sign-out failed:', err)
    }
  }

  const handleInvitePlayer = useCallback((payload) => withSave(async () => {
    if (!currentTeamId) throw new Error('Select a team first.')
    if (!currentTeamMembership) throw new Error('You are not a member of this team.')
    if (!['captain', 'admin'].includes(currentTeamMembership.role)) {
      throw new Error('Only captains and admins can invite players.')
    }

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
      role: existingMembership?.role || 'member',
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

    await teamModel.addTeamMembership({ teamId: team.id, playerId: player.id, role: 'member', status: 'active' })
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
    if (currentTeamMembership?.role !== 'captain') throw new Error('Only the captain can change team roles.')
    if (!member?.id) throw new Error('Member is required.')
    if (!['captain', 'admin', 'member'].includes(nextRole)) throw new Error('Invalid role.')

    if (member.playerId === currentTeamMembership.playerId && nextRole !== 'captain') {
      throw new Error('Captain cannot remove their own captaincy without transferring it first.')
    }
    if (nextRole === 'captain') {
      await teamModel.updateTeamMembership({ membershipId: member.id, role: 'captain' })
      const currentCaptain = teamRoster.members.find(entry => entry.playerId === currentTeamMembership.playerId)
      if (currentCaptain) {
        await teamModel.updateTeamMembership({ membershipId: currentCaptain.id, role: 'member' })
      }
    } else {
      if (member.role === 'captain') throw new Error('Transfer captaincy instead of demoting the captain directly.')
      await teamModel.updateTeamMembership({ membershipId: member.id, role: nextRole })
    }

    await Promise.all([loadTeamRoster(currentTeamId), refreshMemberContext(session?.user)])
  }), [currentTeamId, currentTeamMembership, loadTeamRoster, refreshMemberContext, session?.user, teamRoster.members])

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
            <div className="flex items-center gap-2">
              <button onClick={() => navigate('/profile')} className="text-xs text-zinc-300 hover:text-white bg-zinc-800 border border-zinc-700 rounded-full px-3 py-1.5 whitespace-nowrap">
                Profile
              </button>
              <button onClick={handleSignOut} className="text-xs text-zinc-300 hover:text-white bg-zinc-800 border border-zinc-700 rounded-full px-3 py-1.5 whitespace-nowrap">
                Sign out
              </button>
            </div>
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
              onViewProfile={() => navigate('/profile')}
            />

            {route.name === 'profile' ? (
              <PlayerProfilePage
                profile={profile}
                memberships={memberContext.memberships}
                onSaveProfile={handleSaveProfile}
                onCreateTeam={() => navigate('/teams/new')}
                onJoinTeam={() => navigate('/teams/join')}
                saving={saving}
              />
            ) : route.name === 'create-team' ? (
              <CreateTeamPage onCreateTeam={handleCreateTeam} saving={saving} />
            ) : route.name === 'join-team' ? (
              <JoinTeamPage onJoinTeam={handleJoinTeam} onCreateTeam={() => navigate('/teams/new')} saving={saving} />
            ) : !currentTeamId ? (
              <div className="space-y-3">
                <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 text-sm text-zinc-400">
                  No current team is available for this account yet.
                </div>
                <div className="flex gap-2">
                  <Btn variant="outline" onClick={() => navigate('/teams/join')}>Join a team</Btn>
                  <Btn onClick={() => navigate('/teams/new')}>Create your first team</Btn>
                </div>
              </div>
            ) : loading ? <Spinner /> : error ? <ErrorScreen error={error} onRetry={() => load(currentTeamId)} /> : route.name === 'teams' ? (
              <TeamsIndex
                memberships={memberContext.memberships}
                currentTeamId={currentTeamId}
                onSwitchTeam={teamId => switchTeam(teamId, 'app')}
                onOpenTeam={teamId => switchTeam(teamId, 'team')}
                onCreateTeam={() => navigate('/teams/new')}
                onJoinTeam={() => navigate('/teams/join')}
              />
            ) : route.name === 'team' ? (
              <TeamMembersPage
                team={currentTeamMembership?.team}
                membership={currentTeamMembership}
                members={teamRoster.members}
                invites={teamRoster.invites}
                onOpenApp={() => navigate('/')}
                onBackToTeams={() => navigate('/teams')}
                onRefresh={() => loadTeamRoster(currentTeamId)}
                onInvitePlayer={handleInvitePlayer}
                onUpdateMemberRole={handleUpdateMemberRole}
                saving={saving}
              />
            ) : (
              <>
                <div className="mb-4 bg-zinc-900/70 border border-zinc-800 rounded-xl px-3 py-2 text-xs text-zinc-400">
                  Working in <span className="text-white font-bold">{currentTeamMembership?.team.name ?? 'Selected team'}</span>.
                </div>
                {tab === 0 && <Dashboard players={players} fineTypes={fineTypes} seasons={seasons} matches={matches} currentTeam={currentTeamMembership?.team} />}
                {tab === 1 && <MatchesTab players={players} fineTypes={fineTypes} seasons={seasons} matches={matches} setMatches={setMatches} withSave={withSave} currentTeamId={currentTeamId} currentTeamRole={currentTeamMembership?.role} />}
                {tab === 2 && <FinesTab players={players} matches={matches} setMatches={setMatches} withSave={withSave} currentTeamId={currentTeamId} currentTeamRole={currentTeamMembership?.role} />}
                {tab === 3 && canManageTeam(currentTeamMembership?.role) && <SetupTab players={players} fineTypes={fineTypes} seasons={seasons} matches={matches}
                                setPlayers={setPlayers} setFineTypes={setFineTypes} setSeasons={setSeasons} setMatches={setMatches} withSave={withSave}
                                currentUser={session?.user} profile={profile} setProfile={setProfile} currentTeamId={currentTeamId} currentTeam={currentTeamMembership?.team} currentTeamRole={currentTeamMembership?.role} />}
                {tab === 3 && !canManageTeam(currentTeamMembership?.role) && <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4 text-sm text-zinc-400">Only captains and vice-captains can access team setup tools.</div>}
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
