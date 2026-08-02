import { useEffect, useMemo, useState } from 'react'
import { Badge, Btn, Input, Modal, Sel, SegmentedControl } from '../App'
import * as auth from '../lib/auth'
import * as teamModel from '../lib/teamModel'
import * as rackem from '../lib/rackem'
import { validateTeamLogo } from '../lib/teamLogo'
import { TEAM_ROLE } from '../lib/permissions'
import TeamSubscriptionPanel from './TeamSubscriptionPanel'

const TABS = [
  { id: 'players', label: 'Players' },
  { id: 'invites', label: 'Invites' },
  { id: 'fines', label: 'Fines' },
  { id: 'seasons', label: 'Seasons' },
  { id: 'subscription', label: 'Subscription' },
  { id: 'settings', label: 'Settings' },
  { id: 'security', label: 'Security' },
]

function SummaryCard({ label, value, accent = 'text-white' }) {
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-800/70 px-3 py-3">
      <p className="text-zinc-400 text-xs uppercase tracking-wider">{label}</p>
      <p className={`text-xl font-bold mt-1 ${accent}`}>{value}</p>
    </div>
  )
}

function EmptyState({ children }) {
  return <p className="text-sm text-zinc-400 py-6 text-center">{children}</p>
}

export default function TeamManagementPage({
  team,
  membership,
  members,
  invites,
  fineTypes,
  seasons,
  saving,
  onOpenApp,
  onRefresh,
  onInvitePlayer,
  onUpdateMemberRole,
  onSavePlayerDetails,
  onRemoveMember,
  onRevokeInvite,
  onResendInvite,
  onAddFineType,
  onUpdateFineType,
  onDeleteFineType,
  onAddSeason,
  onUpdateSeason,
  onDeleteSeason,
  onImportRackemSeason,
  onRefreshRackemSeason,
  onUpdateTeamSettings,
  onSetUnlockCode,
  onChangeUnlockCode,
  onRequestUnlockCodeReset,
  onAdminResetUnlockCode,
  platformRole,
}) {
  const [activeTab, setActiveTab] = useState('players')
  const canManageTeam = teamModel.canManageTeam(membership?.role, platformRole)
  const canManageRoles = teamModel.canCaptainManageRoles(membership?.role)

  useEffect(() => {
    setActiveTab('players')
  }, [team?.id])

  if (!team || !membership) {
    return (
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 text-sm text-zinc-400">
        Team not found.
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex gap-2">
        <Btn variant="outline" size="sm" onClick={onOpenApp}>← Back</Btn>
        <Btn variant="outline" size="sm" onClick={onRefresh}>Refresh</Btn>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-start justify-between gap-3 flex-wrap">
          <div>
            <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">Team Management</p>
            <h2 className="font-display text-2xl font-bold text-white mt-1">{team.name}</h2>
            <p className="text-sm text-zinc-400 mt-1">Team-scoped administration for players, invites, fine types, and seasons.</p>
          </div>
          <Badge color={canManageTeam ? 'amber' : 'gray'}>{teamModel.getRoleLabel(membership.role)}</Badge>
        </div>

        <div className="grid grid-cols-2 gap-2 mt-4 sm:grid-cols-4">
          <SummaryCard label="Team" value={team.name} />
          <SummaryCard label="Your role" value={teamModel.getRoleLabel(membership.role)} accent="text-amber-400" />
          <SummaryCard label="Active members" value={members.length} />
          <SummaryCard label="Pending invites" value={invites.length} accent={invites.length ? 'text-blue-400' : 'text-white'} />
        </div>
      </div>

      <SegmentedControl
        options={TABS.map(tab => ({ value: tab.id, label: tab.label }))}
        value={activeTab}
        onChange={setActiveTab}
        wrap
        minItemWidth="6.5rem"
      />

      {activeTab === 'players' && (
        <PlayersTab
          members={members}
          membership={membership}
          canManageTeam={canManageTeam}
          canManageRoles={canManageRoles}
          saving={saving}
          onUpdateMemberRole={onUpdateMemberRole}
          onSavePlayerDetails={onSavePlayerDetails}
          onRemoveMember={onRemoveMember}
        />
      )}

      {activeTab === 'subscription' && (
        <TeamSubscriptionPanel team={team} seasons={seasons} canManageTeam={canManageTeam} />
      )}

      {activeTab === 'invites' && (
        <InvitesTab
          team={team}
          membership={membership}
          invites={invites}
          canManageTeam={canManageTeam}
          saving={saving}
          onInvitePlayer={onInvitePlayer}
          onRevokeInvite={onRevokeInvite}
          onResendInvite={onResendInvite}
        />
      )}

      {activeTab === 'fines' && (
        <FineTypesTab
          fineTypes={fineTypes}
          canManageTeam={canManageTeam}
          saving={saving}
          onAddFineType={onAddFineType}
          onUpdateFineType={onUpdateFineType}
          onDeleteFineType={onDeleteFineType}
        />
      )}

      {activeTab === 'seasons' && (
        <SeasonsTab
          seasons={seasons}
          team={team}
          canManageTeam={canManageTeam}
          saving={saving}
          onAddSeason={onAddSeason}
          onUpdateSeason={onUpdateSeason}
          onDeleteSeason={onDeleteSeason}
          onImportRackemSeason={onImportRackemSeason}
          onRefreshRackemSeason={onRefreshRackemSeason}
        />
      )}

      {activeTab === 'security' && (
        <TeamSecurityTab
          team={team}
          membership={membership}
          platformRole={platformRole}
          members={members}
          saving={saving}
          onSetUnlockCode={onSetUnlockCode}
          onChangeUnlockCode={onChangeUnlockCode}
          onRequestUnlockCodeReset={onRequestUnlockCodeReset}
          onAdminResetUnlockCode={onAdminResetUnlockCode}
        />
      )}

      {activeTab === 'settings' && (
        <TeamSettingsTab
          team={team}
          canManageTeam={canManageTeam}
          saving={saving}
          onUpdateTeamSettings={onUpdateTeamSettings}
        />
      )}
    </div>
  )
}

function TeamSettingsTab({ team, canManageTeam, saving, onUpdateTeamSettings }) {
  const [settings, setSettings] = useState({
    subsEnabled: team?.subsEnabled !== false,
    driversVoidSubs: team?.driversVoidSubs !== false,
    subAmount: Number(team?.subAmount ?? 0.50).toFixed(2),
    rackemImportEnabled: Boolean(team?.rackemImportEnabled),
    rackemLeagueSlug: team?.rackemLeagueSlug ?? '',
    rackemLeagueName: team?.rackemLeagueName ?? '',
    rackemTeamId: team?.rackemTeamId ?? '',
    rackemTeamName: team?.rackemTeamName ?? '',
    rackemTeamUrl: team?.rackemTeamUrl ?? '',
  })
  const [logoFile, setLogoFile] = useState(null)
  const [logoPreview, setLogoPreview] = useState('')
  const [status, setStatus] = useState({ error: '', success: '' })
  const [rackemLeagues, setRackemLeagues] = useState([])
  const [rackemTeams, setRackemTeams] = useState([])
  const [rackemLoading, setRackemLoading] = useState('')

  useEffect(() => {
    setSettings({
      subsEnabled: team?.subsEnabled !== false,
      driversVoidSubs: team?.driversVoidSubs !== false,
      subAmount: Number(team?.subAmount ?? 0.50).toFixed(2),
      rackemImportEnabled: Boolean(team?.rackemImportEnabled),
      rackemLeagueSlug: team?.rackemLeagueSlug ?? '',
      rackemLeagueName: team?.rackemLeagueName ?? '',
      rackemTeamId: team?.rackemTeamId ?? '',
      rackemTeamName: team?.rackemTeamName ?? '',
      rackemTeamUrl: team?.rackemTeamUrl ?? '',
    })
    setLogoFile(null)
    setLogoPreview('')
    setStatus({ error: '', success: '' })
  }, [team?.id, team?.subsEnabled, team?.driversVoidSubs, team?.subAmount, team?.logoUrl])

  useEffect(() => {
    if (!settings.rackemImportEnabled || rackemLeagues.length) return
    setRackemLoading('leagues')
    rackem.listRackemLeagues()
      .then(setRackemLeagues)
      .catch(error => setStatus({ error: error?.message ?? 'Could not load RackEm leagues.', success: '' }))
      .finally(() => setRackemLoading(''))
  }, [settings.rackemImportEnabled, rackemLeagues.length])

  useEffect(() => {
    if (!settings.rackemImportEnabled || !settings.rackemLeagueSlug) {
      setRackemTeams([])
      return
    }
    setRackemLoading('teams')
    rackem.listRackemTeams(settings.rackemLeagueSlug)
      .then(setRackemTeams)
      .catch(error => setStatus({ error: error?.message ?? 'Could not load RackEm teams.', success: '' }))
      .finally(() => setRackemLoading(''))
  }, [settings.rackemImportEnabled, settings.rackemLeagueSlug])

  useEffect(() => () => {
    if (logoPreview) URL.revokeObjectURL(logoPreview)
  }, [logoPreview])

  const chooseLogo = event => {
    const file = event.target.files?.[0] ?? null
    if (!file) return
    try {
      validateTeamLogo(file)
      if (logoPreview) URL.revokeObjectURL(logoPreview)
      setLogoFile(file)
      setLogoPreview(URL.createObjectURL(file))
      setStatus({ error: '', success: '' })
    } catch (err) {
      event.target.value = ''
      setStatus({ error: err?.message ?? 'Choose a valid image.', success: '' })
    }
  }

  const saveSettings = async () => {
    setStatus({ error: '', success: '' })
    try {
      await onUpdateTeamSettings(settings, logoFile)
      setLogoFile(null)
      setLogoPreview('')
      setStatus({ error: '', success: 'Team settings saved.' })
    } catch (err) {
      setStatus({ error: err?.message ?? 'Failed to save team settings.', success: '' })
    }
  }

  return (
    <div className="space-y-3">
      <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
        <h3 className="font-bold text-white">Match and subs settings</h3>
        <p className="mt-1 text-xs text-zinc-400">Control how this team records match subs and driver exemptions.</p>
      </div>

      <label className="flex items-center justify-between gap-3 rounded-xl border border-zinc-700 bg-zinc-800 px-3 py-3">
        <div>
          <p className="text-sm font-bold text-white">Enable subs</p>
          <p className="text-xs text-zinc-400">Add the standard sub charge when players are selected.</p>
        </div>
        <input
          type="checkbox"
          checked={settings.subsEnabled}
          onChange={event => setSettings(current => ({ ...current, subsEnabled: event.target.checked }))}
          disabled={!canManageTeam || saving}
          className="h-5 w-5 accent-amber-500"
        />
      </label>

      <label className={`flex items-center justify-between gap-3 rounded-xl border border-zinc-700 bg-zinc-800 px-3 py-3 ${!settings.subsEnabled ? 'opacity-50' : ''}`}>
        <div>
          <p className="text-sm font-bold text-white">Drivers void subs</p>
          <p className="text-xs text-zinc-400">On away matches, marked drivers do not pay a sub.</p>
        </div>
        <input
          type="checkbox"
          checked={settings.driversVoidSubs}
          onChange={event => setSettings(current => ({ ...current, driversVoidSubs: event.target.checked }))}
          disabled={!canManageTeam || saving || !settings.subsEnabled}
          className="h-5 w-5 accent-amber-500"
        />
      </label>

      <div className={`rounded-xl border border-zinc-700 bg-zinc-800 px-3 py-3 ${!settings.subsEnabled ? 'opacity-50' : ''}`}>
        <Input
          label="Sub value (£)"
          type="number"
          min="0"
          max="100"
          step="0.01"
          value={settings.subAmount}
          onChange={event => setSettings(current => ({ ...current, subAmount: event.target.value }))}
          disabled={!canManageTeam || saving || !settings.subsEnabled}
        />
        <p className="-mt-2 text-xs text-zinc-400">Applied to players newly added to a match. Defaults to £0.50.</p>
      </div>

      <div className="rounded-xl border border-zinc-700 bg-zinc-800 px-3 py-3">
        <p className="text-sm font-bold text-white">Team logo</p>
        <p className="mt-1 text-xs text-zinc-400">
          Best results: a 1200 × 400 px landscape JPG, PNG, or WebP. Maximum upload 5 MB. The app resizes and optimises it automatically.
        </p>
        {(logoPreview || team?.logoUrl) && (
          <div className="mt-3 overflow-hidden rounded-xl border border-zinc-700 bg-zinc-950">
            <img
              src={logoPreview || team.logoUrl}
              alt={`${team?.name ?? 'Team'} logo preview`}
              className="h-28 w-full object-contain"
            />
          </div>
        )}
        <label className={`mt-3 inline-flex cursor-pointer items-center justify-center rounded-lg px-4 py-2 text-sm font-bold transition ${
          canManageTeam && !saving
            ? 'bg-zinc-700 text-white hover:bg-zinc-600'
            : 'cursor-not-allowed bg-zinc-700 text-zinc-500'
        }`}>
          Choose image
          <input
            type="file"
            accept="image/jpeg,image/png,image/webp"
            onChange={chooseLogo}
            disabled={!canManageTeam || saving}
            className="sr-only"
          />
        </label>
        {logoFile && <p className="mt-2 text-xs text-emerald-400">Ready to upload: {logoFile.name}</p>}
      </div>

      <div className="rounded-xl border border-zinc-700 bg-zinc-800 px-3 py-3">
        <label className="flex items-center justify-between gap-3">
          <div>
            <p className="text-sm font-bold text-white">Import from RackEmApp</p>
            <p className="text-xs text-zinc-400">Connect this team to its public RackEm league and team profile.</p>
          </div>
          <input
            type="checkbox"
            checked={settings.rackemImportEnabled}
            onChange={event => setSettings(current => ({
              ...current,
              rackemImportEnabled: event.target.checked,
            }))}
            disabled={!canManageTeam || saving}
            className="h-5 w-5 accent-amber-500"
          />
        </label>

        {settings.rackemImportEnabled && (
          <div className="mt-4 border-t border-zinc-700 pt-4">
            <Sel
              label="RackEmApp league"
              value={settings.rackemLeagueSlug}
              disabled={!canManageTeam || saving || rackemLoading === 'leagues'}
              onChange={event => {
                const league = rackemLeagues.find(item => item.slug === event.target.value)
                setSettings(current => ({
                  ...current,
                  rackemLeagueSlug: league?.slug ?? '',
                  rackemLeagueName: league?.name ?? '',
                  rackemTeamId: '',
                  rackemTeamName: '',
                  rackemTeamUrl: '',
                }))
              }}
            >
              <option value="">{rackemLoading === 'leagues' ? 'Loading leagues…' : 'Select a league'}</option>
              {rackemLeagues.map(league => <option key={league.slug} value={league.slug}>{league.name}</option>)}
            </Sel>

            <Sel
              label="RackEmApp team"
              value={settings.rackemTeamId}
              disabled={!canManageTeam || saving || !settings.rackemLeagueSlug || rackemLoading === 'teams'}
              onChange={event => {
                const rackemTeam = rackemTeams.find(item => item.id === event.target.value)
                setSettings(current => ({
                  ...current,
                  rackemTeamId: rackemTeam?.id ?? '',
                  rackemTeamName: rackemTeam?.name ?? '',
                  rackemTeamUrl: rackemTeam?.url ?? '',
                }))
              }}
            >
              <option value="">{rackemLoading === 'teams' ? 'Loading teams…' : 'Select a team'}</option>
              {rackemTeams.map(rackemTeam => <option key={rackemTeam.id} value={rackemTeam.id}>{rackemTeam.name}</option>)}
            </Sel>
            <p className="text-xs text-zinc-400">RackEm team identifiers change each season. RooBin will use Team History to discover connected seasons.</p>
          </div>
        )}
      </div>

      {status.error && <p className="text-sm text-red-400">{status.error}</p>}
      {status.success && <p className="text-sm text-emerald-400">{status.success}</p>}
      <Btn onClick={saveSettings} disabled={!canManageTeam || saving}>
        {saving ? 'Saving...' : 'Save settings'}
      </Btn>
    </div>
  )
}

function PlayersTab({ members, membership, canManageTeam, canManageRoles, saving, onUpdateMemberRole, onSavePlayerDetails, onRemoveMember }) {
  const [selectedMember, setSelectedMember] = useState(null)
  const [status, setStatus] = useState({ error: '', success: '' })

  useEffect(() => {
    setSelectedMember(null)
    setStatus({ error: '', success: '' })
  }, [membership?.playerId])

  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
      <div className="flex items-center justify-between gap-3 mb-3">
        <div>
          <h3 className="font-bold text-white">Players</h3>
          <p className="text-xs text-zinc-400">Roster and role visibility for the selected team.</p>
        </div>
        <Badge color="blue">{members.length}</Badge>
      </div>

      {status.error && <p className="mb-3 text-sm text-red-400">{status.error}</p>}
      {status.success && <p className="mb-3 text-sm text-emerald-400">{status.success}</p>}

      <div className="space-y-2">
        {!members.length ? (
          <EmptyState>No active members yet.</EmptyState>
        ) : members.map(member => {
          const isSelf = member.playerId === membership?.playerId
          const roleOptions = [
            { value: TEAM_ROLE.VICE_CAPTAIN, label: 'Promote to Vice-captain' },
            { value: TEAM_ROLE.MEMBER, label: 'Demote to Member' },
            { value: TEAM_ROLE.CAPTAIN, label: 'Transfer Captaincy' },
          ].filter(option => {
            if (!canManageRoles) return false
            if (member.role === option.value) return false
            if (member.role === TEAM_ROLE.CAPTAIN && option.value !== TEAM_ROLE.CAPTAIN) return false
            if (isSelf && option.value !== TEAM_ROLE.CAPTAIN) return false
            return true
          })

          const contactSummary = [member.email, member.mobile].filter(Boolean).join(' · ') || 'No email or mobile saved'

          return (
            <button
              key={member.id}
              type="button"
              onClick={() => {
                setSelectedMember(member)
                setStatus({ error: '', success: '' })
              }}
              className={`w-full rounded-xl border px-3 py-3 flex items-center justify-between gap-3 text-left transition ${selectedMember?.id === member.id ? 'border-amber-500 bg-zinc-800' : 'border-zinc-800 bg-zinc-800/80 hover:border-zinc-700'}`}
            >
              <div>
                <p className="text-sm font-medium text-white">{member.playerName || 'Unknown player'}{isSelf ? ' (You)' : ''}</p>
                <p className="text-xs text-zinc-400 mt-1">{teamModel.getRoleLabel(member.role)}</p>
                <p className="text-xs text-zinc-500 mt-1">{contactSummary}</p>
              </div>
              <div className="flex items-center gap-2 flex-wrap justify-end">
                <Badge color="amber">{teamModel.getRoleLabel(member.role)}</Badge>
                {!!roleOptions.length && (
                  <select
                    className="bg-zinc-900 border border-zinc-700 rounded-lg px-2 py-1.5 text-xs text-white"
                    defaultValue=""
                    disabled={saving}
                    onClick={event => event.stopPropagation()}
                    onChange={async event => {
                      const nextRole = event.target.value
                      event.target.value = ''
                      if (!nextRole) return
                      setStatus({ error: '', success: '' })
                      try {
                        await onUpdateMemberRole(member, nextRole)
                        setSelectedMember(current => current?.id === member.id ? { ...current, role: nextRole } : current)
                        setStatus({ error: '', success: `${member.playerName || 'Player'} role updated.` })
                      } catch (err) {
                        setStatus({ error: err?.message ?? 'Failed to update player role.', success: '' })
                      }
                    }}
                  >
                    <option value="">Role actions</option>
                    {roleOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                  </select>
                )}
              </div>
            </button>
          )
        })}
      </div>

      {selectedMember && (
        <PlayerDetailsPanel
          key={selectedMember.id}
          member={selectedMember}
          membership={membership}
          canManageTeam={canManageTeam}
          canManageRoles={canManageRoles}
          saving={saving}
          onClose={() => setSelectedMember(null)}
          onSave={async payload => {
            setStatus({ error: '', success: '' })
            try {
              await onSavePlayerDetails(payload)
              setStatus({ error: '', success: `${payload.displayName} details updated.` })
            } catch (err) {
              setStatus({ error: err?.message ?? 'Failed to save player details.', success: '' })
              throw err
            }
          }}
          onRemove={async (memberToRemove, unlockCode) => {
            setStatus({ error: '', success: '' })
            try {
              await onRemoveMember(memberToRemove, unlockCode)
              setSelectedMember(null)
              setStatus({ error: '', success: `${memberToRemove.playerName || 'Player'} removed from the team.` })
            } catch (err) {
              setStatus({ error: err?.message ?? 'Failed to remove player from team.', success: '' })
              throw err
            }
          }}
        />
      )}
    </div>
  )
}

function PlayerDetailsPanel({ member, membership, canManageTeam, canManageRoles, saving, onClose, onSave, onRemove }) {
  const [form, setForm] = useState({
    displayName: member.playerName || '',
    email: member.email || '',
    mobile: member.mobile || '',
    role: member.role || TEAM_ROLE.MEMBER,
  })
  const [error, setError] = useState('')
  const [confirmingRemoval, setConfirmingRemoval] = useState(false)
  const [unlockCode, setUnlockCode] = useState('')
  const canEditPlayer = canManageTeam || member.playerId === membership?.playerId
  const canRemove = canManageTeam && member.role !== TEAM_ROLE.CAPTAIN && member.playerId !== membership?.playerId

  useEffect(() => {
    setForm({
      displayName: member.playerName || '',
      email: member.email || '',
      mobile: member.mobile || '',
      role: member.role || TEAM_ROLE.MEMBER,
    })
    setError('')
    setConfirmingRemoval(false)
    setUnlockCode('')
  }, [member])

  return (
    <div className="mt-4 rounded-2xl border border-zinc-800 bg-zinc-950/80 p-4">
      <div className="flex items-start justify-between gap-3 mb-4">
        <div>
          <h4 className="font-bold text-white">Player details</h4>
          <p className="text-xs text-zinc-400">Edit this team member inside the current team context.</p>
        </div>
        <Btn variant="outline" size="sm" onClick={onClose}>Close</Btn>
      </div>

      {error && <p className="mb-3 text-sm text-red-400">{error}</p>}

      <Input label="Display name" value={form.displayName} onChange={event => setForm(current => ({ ...current, displayName: event.target.value }))} disabled={saving || !canEditPlayer} />
      <Input label="Email" type="email" value={form.email} onChange={event => setForm(current => ({ ...current, email: event.target.value }))} disabled={saving || !canEditPlayer} />
      <Input label="Mobile" value={form.mobile} onChange={event => setForm(current => ({ ...current, mobile: event.target.value }))} disabled={saving || !canEditPlayer} />
      <Sel
        label="Role in team"
        value={form.role}
        disabled={!canManageRoles || saving}
        onChange={event => setForm(current => ({ ...current, role: event.target.value }))}
      >
        <option value={TEAM_ROLE.CAPTAIN}>Captain</option>
        <option value={TEAM_ROLE.VICE_CAPTAIN}>Vice-captain</option>
        <option value={TEAM_ROLE.MEMBER}>Member</option>
      </Sel>
      {!canManageRoles && <p className="text-xs text-zinc-500 -mt-2 mb-3">Only the captain can change team roles.</p>}
      {!canEditPlayer && <p className="text-xs text-zinc-500 -mt-2 mb-3">Only captains, vice-captains, or the selected player can edit these details.</p>}

      <div className="flex flex-wrap gap-2">
        <Btn
          disabled={saving || !canEditPlayer || !form.displayName.trim() || !form.email.trim()}
          onClick={async () => {
            try {
              await onSave({
                membershipId: member.id,
                playerId: member.playerId,
                currentRole: member.role,
                ...form,
              })
            } catch (err) {
              setError(err?.message ?? 'Failed to save player details.')
            }
          }}
        >
          {saving ? 'Saving...' : 'Save player'}
        </Btn>
        {canRemove && (
          <>
            {!confirmingRemoval ? (
              <Btn variant="danger" onClick={() => setConfirmingRemoval(true)} disabled={saving}>Remove from team</Btn>
            ) : (
              <>
                <Input label="Unlock code" type="password" value={unlockCode} onChange={event => setUnlockCode(event.target.value)} disabled={saving} />
                <Btn variant="danger" onClick={async () => {
                  try {
                    await onRemove(member, unlockCode)
                  } catch (err) {
                    setError(err?.message ?? 'Failed to remove player from team.')
                  }
                }} disabled={saving || !unlockCode.trim()}>
                  Confirm remove
                </Btn>
                <Btn variant="outline" onClick={() => setConfirmingRemoval(false)} disabled={saving}>Cancel</Btn>
              </>
            )}
          </>
        )}
      </div>
    </div>
  )
}

function InvitesTab({ team, membership, invites, canManageTeam, saving, onInvitePlayer, onRevokeInvite, onResendInvite }) {
  const [form, setForm] = useState({ displayName: '', email: '' })
  const [status, setStatus] = useState({ error: '', success: '', info: [] })

  useEffect(() => {
    setForm({ displayName: '', email: '' })
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
      setStatus({ error: '', success: result.message, info: result.notes ?? [] })
      setForm({ displayName: '', email: '' })
    } catch (err) {
      setStatus({ error: err?.message ?? 'Failed to invite player.', success: '', info: [] })
    }
  }

  return (
    <div className="space-y-4">
      <form onSubmit={submit} className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h3 className="font-bold text-white">Invite player by email</h3>
            <p className="text-xs text-zinc-400">Invites stay scoped to {team.name} and keep current permission rules.</p>
          </div>
          <Badge color={canManageTeam ? 'green' : 'red'}>{canManageTeam ? 'Can invite' : 'View only'}</Badge>
        </div>
        <Input label="Display name" value={form.displayName} onChange={event => setForm(current => ({ ...current, displayName: event.target.value }))} placeholder="Player display name" disabled={!canManageTeam || saving} />
        <Input label="Email" type="email" required value={form.email} onChange={event => setForm(current => ({ ...current, email: event.target.value }))} placeholder="player@example.com" disabled={!canManageTeam || saving} />
        {!canManageTeam && <p className="mb-3 text-sm text-zinc-400">Only captains and vice-captains can send invites.</p>}
        {status.error && <p className="mb-3 text-sm text-red-400">{status.error}</p>}
        {status.success && <p className="mb-2 text-sm text-emerald-400">{status.success}</p>}
        {!!status.info.length && (
          <ul className="mb-3 space-y-1 text-xs text-zinc-400">
            {status.info.map(note => <li key={note}>• {note}</li>)}
          </ul>
        )}
        <Btn type="submit" disabled={!canManageTeam || saving || !form.displayName.trim() || !form.email.trim()}>
          {saving ? 'Inviting...' : 'Invite player'}
        </Btn>
      </form>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h3 className="font-bold text-white">Pending invites</h3>
            <p className="text-xs text-zinc-400">Outstanding invitations for this team only.</p>
          </div>
          <Badge color="blue">{invites.length}</Badge>
        </div>
        <div className="space-y-2">
          {!invites.length ? (
            <EmptyState>No pending invites.</EmptyState>
          ) : invites.map(invite => (
            <div key={invite.id} className="rounded-xl border border-zinc-800 bg-zinc-800/80 px-3 py-3 flex items-center justify-between gap-3">
              <div>
                <p className="text-sm font-medium text-white">{invite.playerName || invite.email}</p>
                <p className="text-xs text-zinc-500">{invite.email}{invite.invitedAt ? ` · sent ${new Date(invite.invitedAt).toLocaleDateString('en-GB')}` : ''}</p>
              </div>
              <div className="flex items-center gap-2 flex-wrap justify-end">
                <Badge color="gray">{teamModel.getRoleLabel(invite.role)}</Badge>
                <Badge color="blue">{invite.status || 'pending'}</Badge>
                {canManageTeam && (
                  <>
                    <Btn
                      size="sm"
                      variant="outline"
                      disabled={saving}
                      onClick={async () => {
                        setStatus({ error: '', success: '', info: [] })
                        try {
                          const result = await onResendInvite(invite)
                          setStatus({ error: '', success: result?.message ?? `Invite resent to ${invite.email}.`, info: [] })
                        } catch (err) {
                          setStatus({ error: err?.message ?? 'Failed to resend invite.', success: '', info: [] })
                        }
                      }}
                    >
                      Resend
                    </Btn>
                    <Btn
                      size="sm"
                      variant="danger"
                      disabled={saving}
                      onClick={async () => {
                        setStatus({ error: '', success: '', info: [] })
                        try {
                          await onRevokeInvite(invite)
                          setStatus({ error: '', success: `Invite revoked for ${invite.email}.`, info: [] })
                        } catch (err) {
                          setStatus({ error: err?.message ?? 'Failed to revoke invite.', success: '', info: [] })
                        }
                      }}
                    >
                      Revoke
                    </Btn>
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="rounded-2xl border border-zinc-800 bg-zinc-900/70 p-4 text-sm text-zinc-400">
        Your access for this team is <span className="text-white font-bold">{teamModel.getRoleLabel(membership.role)}</span>.
      </div>
    </div>
  )
}

function FineTypesTab({ fineTypes, canManageTeam, saving, onAddFineType, onUpdateFineType, onDeleteFineType }) {
  const [fineInput, setFineInput] = useState({ name: '', cost: '' })
  const [editFineType, setEditFineType] = useState(null)
  const [confirmDeleteFine, setConfirmDeleteFine] = useState(null)
  const [finePinInput, setFinePinInput] = useState('')
  const [finePinError, setFinePinError] = useState('')
  const sortedFineTypes = useMemo(() => [...fineTypes].sort((a, b) => a.cost - b.cost || a.name.localeCompare(b.name)), [fineTypes])

  return (
    <div className="space-y-4">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-start justify-between gap-3 mb-4 flex-wrap">
          <div>
            <h3 className="font-bold text-white">Team fine types</h3>
            <p className="text-xs text-zinc-400">Manage the fine definitions used by this team&apos;s matches, fine recording, and reporting.</p>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <Badge color={canManageTeam ? 'green' : 'red'}>{canManageTeam ? 'Editable' : 'View only'}</Badge>
            <Badge color="blue">{sortedFineTypes.length} {sortedFineTypes.length === 1 ? 'fine type' : 'fine types'}</Badge>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
          <SummaryCard label="Configured fines" value={sortedFineTypes.length} accent="text-amber-400" />
          <SummaryCard label="Lowest price" value={sortedFineTypes.length ? `£${sortedFineTypes[0].cost.toFixed(2)}` : '—'} />
          <SummaryCard label="Highest price" value={sortedFineTypes.length ? `£${sortedFineTypes[sortedFineTypes.length - 1].cost.toFixed(2)}` : '—'} />
        </div>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h4 className="font-bold text-white">Add fine type</h4>
            <p className="text-xs text-zinc-400">New fine types are created for the selected team only.</p>
          </div>
        </div>
        <Input label="Fine name" value={fineInput.name} onChange={event => setFineInput(current => ({ ...current, name: event.target.value }))} disabled={!canManageTeam || saving} />
        <Input label="Current price (£)" type="number" step="0.10" min="0" value={fineInput.cost} onChange={event => setFineInput(current => ({ ...current, cost: event.target.value }))} disabled={!canManageTeam || saving} />
        <Btn
          onClick={async () => {
            await onAddFineType(fineInput)
            setFineInput({ name: '', cost: '' })
          }}
          disabled={!canManageTeam || saving || !fineInput.name.trim() || !fineInput.cost}
        >
          Add fine type
        </Btn>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h4 className="font-bold text-white">Configured fine types</h4>
            <p className="text-xs text-zinc-400">Update names and prices here. This team-scoped list reuses the existing fine type create, edit, and delete flow.</p>
          </div>
        </div>
        <div className="space-y-2">
          {!sortedFineTypes.length ? (
            <EmptyState>No fine types configured yet.</EmptyState>
          ) : sortedFineTypes.map(fineType => (
            <div key={fineType.id} className="flex items-center justify-between bg-zinc-800 rounded-lg px-3 py-3 gap-3">
              <div className="space-y-1">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="text-white text-sm font-medium">{fineType.name}</span>
                  <Badge color="amber">£{fineType.cost.toFixed(2)}</Badge>
                </div>
                <p className="text-xs text-zinc-500">Price changes apply only to this team&apos;s fine configuration.</p>
              </div>
              {canManageTeam && (
                <div className="flex items-center gap-2 shrink-0">
                  <button onClick={() => setEditFineType({ id: fineType.id, name: fineType.name, cost: String(fineType.cost) })} className="text-xs px-2 py-1 rounded-lg bg-zinc-700 hover:bg-zinc-600 text-zinc-300 font-bold">Edit</button>
                  <button onClick={() => { setEditFineType({ id: fineType.id, name: fineType.name, cost: String(fineType.cost) }) }} className="text-xs px-2 py-1 rounded-lg bg-zinc-700 hover:bg-zinc-600 text-zinc-300 font-bold">Change price</button>
                  <button onClick={() => { setConfirmDeleteFine(fineType); setFinePinInput(''); setFinePinError('') }} className="text-xs px-2 py-1 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-300 font-bold">Delete</button>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {confirmDeleteFine && (
        <Modal title="Delete Fine Type" onClose={() => setConfirmDeleteFine(null)}>
          <p className="text-zinc-400 text-sm mb-3">Delete <strong className="text-white">{confirmDeleteFine.name}</strong>? Enter the team unlock code to confirm.</p>
          <Input label="Team unlock code" type="password" value={finePinInput} onChange={event => setFinePinInput(event.target.value)} />
          {finePinError && <p className="text-red-400 text-sm mb-2">{finePinError}</p>}
          <div className="flex gap-2">
            <Btn variant="danger" className="flex-1" onClick={async () => {
              try {
                await onDeleteFineType(confirmDeleteFine, finePinInput)
                setConfirmDeleteFine(null)
                setFinePinInput('')
                setFinePinError('')
              } catch (error) {
                setFinePinError(error?.message ?? 'Fine type could not be deleted.')
              }
            }}>Delete Fine Type</Btn>
            <Btn variant="ghost" className="flex-1" onClick={() => setConfirmDeleteFine(null)}>Cancel</Btn>
          </div>
        </Modal>
      )}

      {editFineType && (
        <Modal title="Edit Fine Type" onClose={() => setEditFineType(null)}>
          <Input label="Fine name" value={editFineType.name} onChange={event => setEditFineType(current => ({ ...current, name: event.target.value }))} />
          <Input label="Cost (£)" type="number" step="0.10" min="0" value={editFineType.cost} onChange={event => setEditFineType(current => ({ ...current, cost: event.target.value }))} />
          <div className="flex gap-2 mt-1">
            <Btn className="flex-1" onClick={async () => {
              await onUpdateFineType(editFineType)
              setEditFineType(null)
            }}>Save</Btn>
            <Btn variant="ghost" className="flex-1" onClick={() => setEditFineType(null)}>Cancel</Btn>
          </div>
        </Modal>
      )}
    </div>
  )
}

function SeasonsTab({
  team,
  seasons,
  canManageTeam,
  saving,
  onAddSeason,
  onUpdateSeason,
  onDeleteSeason,
  onImportRackemSeason,
  onRefreshRackemSeason,
}) {
  const [seasonInput, setSeasonInput] = useState({ name: '', type: 'League' })
  const [editSeason, setEditSeason] = useState(null)
  const [confirmDeleteSeason, setConfirmDeleteSeason] = useState(null)
  const [deletePinInput, setDeletePinInput] = useState('')
  const [deletePinError, setDeletePinError] = useState('')
  const [rackemPreview, setRackemPreview] = useState(null)
  const [selectedRackemSeasons, setSelectedRackemSeasons] = useState([])
  const [rackemStatus, setRackemStatus] = useState({ loading: false, error: '', success: '' })

  const sortedSeasons = useMemo(() => [...seasons].sort((a, b) => a.name.localeCompare(b.name)), [seasons])
  const seasonCountLabel = useMemo(() => `${seasons.length} ${seasons.length === 1 ? 'season' : 'seasons'}`, [seasons.length])

  return (
    <div className="space-y-4">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-start justify-between gap-3 mb-4 flex-wrap">
          <div>
            <h3 className="font-bold text-white">Team seasons</h3>
            <p className="text-xs text-zinc-400">Configure the seasons that organise this team&apos;s fixtures, fines, and reporting.</p>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <Badge color={canManageTeam ? 'green' : 'red'}>{canManageTeam ? seasonCountLabel : 'View only'}</Badge>
            <Badge color="blue">Team scoped</Badge>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
          <SummaryCard label="Configured seasons" value={sortedSeasons.length} accent="text-blue-400" />
          <SummaryCard label="League seasons" value={sortedSeasons.filter(season => season.type !== 'Cup').length} />
          <SummaryCard label="Cup seasons" value={sortedSeasons.filter(season => season.type === 'Cup').length} accent="text-amber-400" />
        </div>
      </div>

      {team?.rackemImportEnabled && team?.rackemLeagueSlug && team?.rackemTeamId && (
        <div className="rounded-2xl border border-amber-800/60 bg-amber-950/20 p-4">
          <div className="flex items-start justify-between gap-3 flex-wrap">
            <div>
              <h4 className="font-bold text-white">RackEmApp seasons</h4>
              <p className="mt-1 text-xs text-zinc-400">
                Connected to {team.rackemTeamName} · {team.rackemLeagueName}
              </p>
            </div>
            <Btn
              size="sm"
              disabled={!canManageTeam || saving || rackemStatus.loading}
              onClick={async () => {
                setRackemStatus({ loading: true, error: '', success: '' })
                try {
                  const preview = await rackem.getRackemTeamPage(team.rackemLeagueSlug, team.rackemTeamId)
                  setRackemPreview(preview)
                  const importedIds = new Set(seasons.filter(item => item.source === 'rackem').map(item => item.sourceSeasonTeamId))
                  setSelectedRackemSeasons(preview.seasons.filter(item => !importedIds.has(item.seasonTeamId) && item.current).map(item => item.seasonTeamId))
                  setRackemStatus({ loading: false, error: '', success: '' })
                } catch (error) {
                  setRackemStatus({ loading: false, error: error?.message ?? 'Could not load RackEm seasons.', success: '' })
                }
              }}
            >
              {rackemStatus.loading ? 'Loading…' : 'Create seasons from RackEmApp'}
            </Btn>
          </div>
          {rackemStatus.error && <p className="mt-3 text-sm text-red-400">{rackemStatus.error}</p>}
          {rackemStatus.success && <p className="mt-3 text-sm text-emerald-400">{rackemStatus.success}</p>}
        </div>
      )}

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h4 className="font-bold text-white">Create season</h4>
            <p className="text-xs text-zinc-400">New seasons are attached to the selected team and available in matches immediately.</p>
          </div>
        </div>
        <Input label="Season name" value={seasonInput.name} onChange={event => setSeasonInput(current => ({ ...current, name: event.target.value }))} disabled={!canManageTeam || saving} />
        <Sel label="Type" value={seasonInput.type} onChange={event => setSeasonInput(current => ({ ...current, type: event.target.value }))} disabled={!canManageTeam || saving}>
          <option value="League">League</option>
          <option value="Cup">Cup</option>
        </Sel>
        <Btn
          onClick={async () => {
            await onAddSeason(seasonInput)
            setSeasonInput({ name: '', type: 'League' })
          }}
          disabled={!canManageTeam || saving || !seasonInput.name.trim()}
        >
          Create season
        </Btn>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <div>
            <h4 className="font-bold text-white">Configured seasons</h4>
            <p className="text-xs text-zinc-400">This view reuses the existing season create, edit, and delete flow for the selected team.</p>
          </div>
        </div>
        <div className="space-y-2">
          {!sortedSeasons.length ? (
            <EmptyState>No seasons configured yet.</EmptyState>
          ) : sortedSeasons.map(season => (
            <div key={season.id} className="flex items-center justify-between bg-zinc-800 rounded-lg px-3 py-3 gap-3">
              <div className="space-y-1">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="text-white text-sm font-medium">{season.name}</span>
                  <Badge color={season.type === 'Cup' ? 'amber' : 'blue'}>{season.type}</Badge>
                  {season.source === 'rackem' && <Badge color="green">RackEmApp</Badge>}
                </div>
                <p className="text-xs text-zinc-500">
                  {season.source === 'rackem'
                    ? `Last refreshed ${season.sourceLastRefreshedAt ? new Date(season.sourceLastRefreshedAt).toLocaleString('en-GB') : 'never'}.`
                    : 'This season is scoped to the selected team and remains available to matches that reference it.'}
                </p>
              </div>
              {canManageTeam && (
                <div className="flex items-center gap-2 shrink-0 flex-wrap justify-end">
                  <button onClick={() => setEditSeason({ ...season })} className="text-xs px-2 py-1 rounded-lg bg-zinc-700 hover:bg-zinc-600 text-zinc-300 font-bold">Edit</button>
                  {season.source === 'rackem' && (
                    <button
                      onClick={async () => {
                        setRackemStatus({ loading: true, error: '', success: '' })
                        try {
                          const result = await onRefreshRackemSeason(season)
                          setRackemStatus({ loading: false, error: '', success: `${season.name}: ${result.created} new, ${result.updated} updated.` })
                        } catch (error) {
                          setRackemStatus({ loading: false, error: error?.message ?? 'Refresh failed.', success: '' })
                        }
                      }}
                      disabled={rackemStatus.loading || saving}
                      className="text-xs px-2 py-1 rounded-lg bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-300 font-bold disabled:opacity-50"
                    >
                      Refresh
                    </button>
                  )}
                  <button onClick={() => { setConfirmDeleteSeason(season); setDeletePinInput(''); setDeletePinError('') }} className="text-xs px-2 py-1 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-300 font-bold">Delete</button>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {rackemPreview && (
        <Modal title="Import RackEmApp seasons" onClose={() => setRackemPreview(null)}>
          <p className="mb-3 text-sm text-zinc-400">Select the seasons to create. Existing imports are disabled.</p>
          <div className="space-y-2">
            {rackemPreview.seasons.map(item => {
              const alreadyImported = seasons.some(season => season.source === 'rackem' && season.sourceSeasonTeamId === item.seasonTeamId)
              const selected = selectedRackemSeasons.includes(item.seasonTeamId)
              return (
                <label key={item.seasonTeamId} className={`flex items-center justify-between gap-3 rounded-xl border border-zinc-700 bg-zinc-800 px-3 py-3 ${alreadyImported ? 'opacity-50' : ''}`}>
                  <div>
                    <p className="text-sm font-bold text-white">{item.name}</p>
                    <p className="text-xs text-zinc-400">{item.current ? 'Current season' : 'Historical season'}{alreadyImported ? ' · Already imported' : ''}</p>
                  </div>
                  <input
                    type="checkbox"
                    checked={alreadyImported || selected}
                    disabled={alreadyImported}
                    onChange={event => setSelectedRackemSeasons(current => event.target.checked
                      ? [...current, item.seasonTeamId]
                      : current.filter(id => id !== item.seasonTeamId))}
                    className="h-5 w-5 accent-amber-500"
                  />
                </label>
              )
            })}
          </div>
          <div className="mt-4 flex gap-2">
            <Btn
              className="flex-1"
              disabled={!selectedRackemSeasons.length || rackemStatus.loading}
              onClick={async () => {
                setRackemStatus({ loading: true, error: '', success: '' })
                try {
                  let created = 0
                  let updated = 0
                  for (const seasonTeamId of selectedRackemSeasons) {
                    const season = rackemPreview.seasons.find(item => item.seasonTeamId === seasonTeamId)
                    const result = await onImportRackemSeason(season)
                    created += result.created
                    updated += result.updated
                  }
                  setRackemPreview(null)
                  setRackemStatus({ loading: false, error: '', success: `Import complete: ${created} matches created and ${updated} updated.` })
                } catch (error) {
                  setRackemStatus({ loading: false, error: error?.message ?? 'Import failed.', success: '' })
                }
              }}
            >
              {rackemStatus.loading ? 'Importing…' : 'Create selected seasons'}
            </Btn>
            <Btn variant="ghost" onClick={() => setRackemPreview(null)}>Cancel</Btn>
          </div>
        </Modal>
      )}

      {confirmDeleteSeason && (
        <Modal title="Delete Season" onClose={() => setConfirmDeleteSeason(null)}>
          <p className="text-zinc-400 text-sm mb-3">Delete <strong className="text-white">{confirmDeleteSeason.name}</strong>? Enter the team unlock code to confirm.</p>
          <Input label="Team unlock code" type="password" value={deletePinInput} onChange={event => setDeletePinInput(event.target.value)} />
          {deletePinError && <p className="text-red-400 text-sm mb-2">{deletePinError}</p>}
          <div className="flex gap-2">
            <Btn variant="danger" className="flex-1" onClick={async () => {
              try {
                await onDeleteSeason(confirmDeleteSeason, deletePinInput)
                setConfirmDeleteSeason(null)
                setDeletePinInput('')
                setDeletePinError('')
              } catch (error) {
                setDeletePinError(error?.message ?? 'Season could not be deleted.')
              }
            }}>Delete Season</Btn>
            <Btn variant="ghost" className="flex-1" onClick={() => setConfirmDeleteSeason(null)}>Cancel</Btn>
          </div>
        </Modal>
      )}

      {editSeason && (
        <Modal title="Edit Season" onClose={() => setEditSeason(null)}>
          <Input label="Season name" value={editSeason.name} onChange={event => setEditSeason(current => ({ ...current, name: event.target.value }))} />
          <Sel label="Type" value={editSeason.type} onChange={event => setEditSeason(current => ({ ...current, type: event.target.value }))}>
            <option value="League">League</option>
            <option value="Cup">Cup</option>
          </Sel>
          <div className="flex gap-2 mt-1">
            <Btn className="flex-1" onClick={async () => {
              await onUpdateSeason(editSeason)
              setEditSeason(null)
            }}>Save</Btn>
            <Btn variant="ghost" className="flex-1" onClick={() => setEditSeason(null)}>Cancel</Btn>
          </div>
        </Modal>
      )}
    </div>
  )
}


function TeamSecurityTab({ team, membership, platformRole, members, saving, onSetUnlockCode, onChangeUnlockCode, onRequestUnlockCodeReset, onAdminResetUnlockCode }) {
  const isCaptain = membership?.role === TEAM_ROLE.CAPTAIN
  const isPlatformAdmin = platformRole === 'admin'
  const captains = useMemo(() => members.filter(member => member.role === TEAM_ROLE.CAPTAIN), [members])
  const recoveryTarget = membership?.preferredAuthMethod === 'whatsapp' && membership?.mobile ? membership.mobile : membership?.email
  const recoveryMethod = membership?.preferredAuthMethod === 'whatsapp' && membership?.mobile ? 'whatsapp' : 'email'
  const [setForm, setSetForm] = useState({ code: '', confirmCode: '' })
  const [changeForm, setChangeForm] = useState({ currentCode: '', nextCode: '', confirmCode: '' })
  const [recovery, setRecovery] = useState({ otp: '', sent: false, sending: false })
  const [status, setStatus] = useState({ error: '', success: '' })

  useEffect(() => {
    setSetForm({ code: '', confirmCode: '' })
    setChangeForm({ currentCode: '', nextCode: '', confirmCode: '' })
    setRecovery({ otp: '', sent: false, sending: false })
    setStatus({ error: '', success: '' })
  }, [team?.id])

  const sendRecoveryOtp = async () => {
    if (!recoveryTarget) {
      setStatus({ error: 'No captain recovery destination is available. Add an email or WhatsApp number to your profile first.', success: '' })
      return
    }
    setStatus({ error: '', success: '' })
    setRecovery(current => ({ ...current, sending: true }))
    try {
      if (recoveryMethod === 'whatsapp') await auth.sendWhatsAppOtp(recoveryTarget)
      else await auth.sendEmailOtp(recoveryTarget)
      setRecovery(current => ({ ...current, sent: true, sending: false }))
      setStatus({ error: '', success: `Verification code sent to ${recoveryTarget}.` })
    } catch (err) {
      setRecovery(current => ({ ...current, sending: false }))
      setStatus({ error: err?.message ?? 'Failed to send recovery code.', success: '' })
    }
  }

  return (
    <div className="space-y-4">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <div className="flex items-start justify-between gap-3 flex-wrap">
          <div>
            <h3 className="font-bold text-white">Team unlock code</h3>
            <p className="text-xs text-zinc-400">Unlock codes are hashed and verified only on the server, with durable attempt limits and immediate rotation on every change or reset.</p>
          </div>
          <Badge color={team?.unlockCodeResetRequired ? 'red' : 'green'}>{team?.unlockCodeResetRequired ? 'Reset required' : 'Configured'}</Badge>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 mt-4">
          <SummaryCard label="Captains notified on reset" value={captains.length || 0} accent="text-blue-400" />
          <SummaryCard label="Last rotated" value={team?.unlockCodeLastRotatedAt ? new Date(team.unlockCodeLastRotatedAt).toLocaleDateString('en-GB') : 'Never'} />
          <SummaryCard label="Your access" value={teamModel.getRoleLabel(membership?.role)} accent="text-amber-400" />
        </div>
        {status.error && <p className="mt-3 text-sm text-red-400">{status.error}</p>}
        {status.success && <p className="mt-3 text-sm text-emerald-400">{status.success}</p>}
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <h4 className="font-bold text-white">Captain self-service</h4>
        <p className="text-xs text-zinc-400 mt-1 mb-3">Only captains can set, change, or recover the team unlock code. Vice-captains can still use the code for protected actions if they know it.</p>
        {!isCaptain && <p className="text-sm text-zinc-500">You must be a captain to manage the team unlock code.</p>}
        {isCaptain && !team?.unlockCodeLastRotatedAt && (
          <div className="rounded-xl border border-zinc-800 bg-zinc-950/70 p-4 mb-4">
            <Input label="New unlock code" type="password" value={setForm.code} onChange={event => setSetForm(current => ({ ...current, code: event.target.value }))} disabled={saving} />
            <Input label="Confirm unlock code" type="password" value={setForm.confirmCode} onChange={event => setSetForm(current => ({ ...current, confirmCode: event.target.value }))} disabled={saving} />
            <Btn disabled={saving || !setForm.code.trim() || setForm.code !== setForm.confirmCode} onClick={async () => {
              try {
                await onSetUnlockCode(setForm.code)
                setSetForm({ code: '', confirmCode: '' })
                setStatus({ error: '', success: 'Team unlock code set successfully.' })
              } catch (err) {
                setStatus({ error: err?.message ?? 'Failed to set unlock code.', success: '' })
              }
            }}>{saving ? 'Saving...' : 'Set unlock code'}</Btn>
          </div>
        )}

        {isCaptain && (
          <div className="rounded-xl border border-zinc-800 bg-zinc-950/70 p-4 space-y-1">
            <Input label="Current unlock code" type="password" value={changeForm.currentCode} onChange={event => setChangeForm(current => ({ ...current, currentCode: event.target.value }))} disabled={saving} />
            <Input label="New unlock code" type="password" value={changeForm.nextCode} onChange={event => setChangeForm(current => ({ ...current, nextCode: event.target.value }))} disabled={saving} />
            <Input label="Confirm new unlock code" type="password" value={changeForm.confirmCode} onChange={event => setChangeForm(current => ({ ...current, confirmCode: event.target.value }))} disabled={saving} />
            <Btn disabled={saving || !changeForm.currentCode.trim() || !changeForm.nextCode.trim() || changeForm.nextCode !== changeForm.confirmCode} onClick={async () => {
              try {
                await onChangeUnlockCode(changeForm.currentCode, changeForm.nextCode)
                setChangeForm({ currentCode: '', nextCode: '', confirmCode: '' })
                setStatus({ error: '', success: 'Team unlock code changed successfully. Previous codes are now invalid.' })
              } catch (err) {
                setStatus({ error: err?.message ?? 'Failed to change unlock code.', success: '' })
              }
            }}>{saving ? 'Updating...' : 'Change unlock code'}</Btn>
          </div>
        )}
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
        <h4 className="font-bold text-white">Forgotten-code recovery</h4>
        <p className="text-xs text-zinc-400 mt-1 mb-3">Captains must verify identity with the same OTP pattern already used by the app before a new unlock code is generated and sent to all captains.</p>
        {isCaptain ? (
          <>
            <p className="text-xs text-zinc-500 mb-3">Recovery destination: {recoveryTarget || 'Not available'}</p>
            <div className="flex gap-2 flex-wrap">
              <Btn variant="outline" disabled={saving || recovery.sending || !recoveryTarget} onClick={sendRecoveryOtp}>
                {recovery.sending ? 'Sending...' : `Send ${recoveryMethod === 'whatsapp' ? 'WhatsApp' : 'email'} OTP`}
              </Btn>
            </div>
            {recovery.sent && (
              <div className="mt-3">
                <Input label="Verification code" value={recovery.otp} onChange={event => setRecovery(current => ({ ...current, otp: event.target.value }))} disabled={saving} />
                <Btn disabled={saving || !recovery.otp.trim()} onClick={async () => {
                  try {
                    await onRequestUnlockCodeReset({ verificationMethod: recoveryMethod, verificationTarget: recoveryTarget, otpToken: recovery.otp })
                    setRecovery({ otp: '', sent: false, sending: false })
                    setStatus({ error: '', success: 'Unlock code reset requested successfully. All captains have been notified if delivery is configured.' })
                  } catch (err) {
                    setStatus({ error: err?.message ?? 'Failed to recover unlock code.', success: '' })
                  }
                }}>{saving ? 'Resetting...' : 'Verify and reset unlock code'}</Btn>
              </div>
            )}
          </>
        ) : <p className="text-sm text-zinc-500">Only captains can run the recovery flow.</p>}
      </div>

      {isPlatformAdmin && (
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <h4 className="font-bold text-white">Platform admin reset</h4>
          <p className="text-xs text-zinc-400 mt-1 mb-3">Admins can rotate a team unlock code and notify captains, but never view, choose, retrieve, or use the generated code.</p>
          <Btn variant="danger" disabled={saving} onClick={async () => {
            try {
              await onAdminResetUnlockCode()
              setStatus({ error: '', success: 'Admin reset complete. A new unlock code was generated and sent to team captains.' })
            } catch (err) {
              setStatus({ error: err?.message ?? 'Failed to trigger admin reset.', success: '' })
            }
          }}>{saving ? 'Resetting...' : 'Trigger admin reset'}</Btn>
        </div>
      )}
    </div>
  )
}
