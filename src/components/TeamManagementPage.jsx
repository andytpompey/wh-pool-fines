import { useEffect, useMemo, useState } from 'react'
import { ADMIN_PIN, Badge, Btn, Input, Modal, Sel, SegmentedControl } from '../App'
import * as teamModel from '../lib/teamModel'

const TABS = [
  { id: 'players', label: 'Players' },
  { id: 'invites', label: 'Invites' },
  { id: 'fines', label: 'Fines' },
  { id: 'seasons', label: 'Seasons' },
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
  onBackToTeams,
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
}) {
  const [activeTab, setActiveTab] = useState('players')
  const canManageTeam = teamModel.canManageTeam(membership?.role)
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
        <Btn variant="outline" size="sm" onClick={onBackToTeams}>← My Teams</Btn>
        <Btn size="sm" onClick={onOpenApp}>Open app</Btn>
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
        fullWidth
        scrollable
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
          canManageTeam={canManageTeam}
          saving={saving}
          onAddSeason={onAddSeason}
          onUpdateSeason={onUpdateSeason}
          onDeleteSeason={onDeleteSeason}
        />
      )}
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
          onRemove={async memberToRemove => {
            setStatus({ error: '', success: '' })
            try {
              await onRemoveMember(memberToRemove)
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
    role: member.role || 'member',
  })
  const [error, setError] = useState('')
  const [confirmingRemoval, setConfirmingRemoval] = useState(false)
  const canEditPlayer = canManageTeam || member.playerId === membership?.playerId
  const canRemove = canManageTeam && member.role !== 'captain' && member.playerId !== membership?.playerId

  useEffect(() => {
    setForm({
      displayName: member.playerName || '',
      email: member.email || '',
      mobile: member.mobile || '',
      role: member.role || 'member',
    })
    setError('')
    setConfirmingRemoval(false)
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
        <option value="captain">Captain</option>
        <option value="admin">Vice-captain</option>
        <option value="member">Player</option>
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
                <Btn variant="danger" onClick={async () => {
                  try {
                    await onRemove(member)
                  } catch (err) {
                    setError(err?.message ?? 'Failed to remove player from team.')
                  }
                }} disabled={saving}>
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
        {!canManageTeam && <p className="mb-3 text-sm text-zinc-400">Only captains and admins can send invites.</p>}
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
          <p className="text-zinc-400 text-sm mb-3">Delete <strong className="text-white">{confirmDeleteFine.name}</strong>? Enter admin PIN to confirm.</p>
          <Input label="Admin PIN" type="password" value={finePinInput} onChange={event => setFinePinInput(event.target.value)} />
          {finePinError && <p className="text-red-400 text-sm mb-2">{finePinError}</p>}
          <div className="flex gap-2">
            <Btn variant="danger" className="flex-1" onClick={async () => {
              if (finePinInput !== ADMIN_PIN) {
                setFinePinError('Incorrect PIN')
                return
              }
              await onDeleteFineType(confirmDeleteFine)
              setConfirmDeleteFine(null)
              setFinePinInput('')
              setFinePinError('')
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

function SeasonsTab({ seasons, canManageTeam, saving, onAddSeason, onUpdateSeason, onDeleteSeason }) {
  const [seasonInput, setSeasonInput] = useState({ name: '', type: 'League' })
  const [editSeason, setEditSeason] = useState(null)
  const [confirmDeleteSeason, setConfirmDeleteSeason] = useState(null)
  const [deletePinInput, setDeletePinInput] = useState('')
  const [deletePinError, setDeletePinError] = useState('')

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
                </div>
                <p className="text-xs text-zinc-500">This season is scoped to the selected team and remains available to matches that reference it.</p>
              </div>
              {canManageTeam && (
                <div className="flex items-center gap-2 shrink-0 flex-wrap justify-end">
                  <button onClick={() => setEditSeason({ ...season })} className="text-xs px-2 py-1 rounded-lg bg-zinc-700 hover:bg-zinc-600 text-zinc-300 font-bold">Edit</button>
                  <button onClick={() => { setConfirmDeleteSeason(season); setDeletePinInput(''); setDeletePinError('') }} className="text-xs px-2 py-1 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-300 font-bold">Delete</button>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {confirmDeleteSeason && (
        <Modal title="Delete Season" onClose={() => setConfirmDeleteSeason(null)}>
          <p className="text-zinc-400 text-sm mb-3">Delete <strong className="text-white">{confirmDeleteSeason.name}</strong>? Enter admin PIN to confirm.</p>
          <Input label="Admin PIN" type="password" value={deletePinInput} onChange={event => setDeletePinInput(event.target.value)} />
          {deletePinError && <p className="text-red-400 text-sm mb-2">{deletePinError}</p>}
          <div className="flex gap-2">
            <Btn variant="danger" className="flex-1" onClick={async () => {
              if (deletePinInput !== ADMIN_PIN) {
                setDeletePinError('Incorrect PIN')
                return
              }
              await onDeleteSeason(confirmDeleteSeason)
              setConfirmDeleteSeason(null)
              setDeletePinInput('')
              setDeletePinError('')
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
