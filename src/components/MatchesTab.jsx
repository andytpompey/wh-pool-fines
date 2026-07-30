import { useEffect, useState } from 'react'
import { Badge, Modal, Input, Sel, Btn, TitleAction, TITLE_ACTION_GRID, TITLE_ACTION_SIZE, uuid, SegmentedControl, formatDate } from '../App'
import * as db from '../lib/db'
import * as teamModel from '../lib/teamModel'
import { APP_ACTION, canAccessAction } from '../lib/accessControl'

// ─── Match Detail ─────────────────────────────────────────────────────────────
function MatchDetail({ match, players, fineTypes, seasons, team, membership, platformRole, currentTeamId, onBack, onSave, onDelete }) {
  const [showAddFine,       setShowAddFine]       = useState(false)
  const [editFine,          setEditFine]           = useState(null)
  const [showAdminPin,      setShowAdminPin]       = useState(false)
  const [pinAction,         setPinAction]          = useState(null)
  const [pinInput,          setPinInput]           = useState('')
  const [pinError,          setPinError]           = useState('')
  const [newFine,           setNewFine]            = useState({ playerId: '', fineTypeId: '' })
  const [activeSection,     setActiveSection]      = useState('fines')
  const [showConfirmSubmit, setShowConfirmSubmit]  = useState(false)

  const season    = seasons.find(s => s.id === match.seasonId)
  const readonly  = match.submitted
  const canManageMatches = canAccessAction({ action: APP_ACTION.EDIT_MATCH, membership, platformRole })
  const canCreateOrEdit = canManageMatches && !readonly
  const canUnlockMatch = canManageMatches && platformRole !== 'admin'
  const playerIds = match.playerIds ?? []
  const driverIds = match.driverIds ?? []
  const subs      = match.subs      ?? []
  const subsEnabled = team?.subsEnabled !== false
  const driversVoidSubs = team?.driversVoidSubs !== false
  const subAmount = Number(team?.subAmount ?? 0.50)
  const isAway = match.venue === 'away'
  const save = patch => onSave(match.id, patch)

  // ── Players ───────────────────────────────────────────────────────────────
  const togglePlayer = playerId => {
    const isIn    = playerIds.includes(playerId)
    const newIds  = isIn ? playerIds.filter(id => id !== playerId) : [...playerIds, playerId]
    let newSubs   = subs
    let newDriverIds = driverIds
    if (isIn) {
      newSubs = subs.filter(s => s.playerId !== playerId)
      newDriverIds = driverIds.filter(id => id !== playerId)
    } else if (subsEnabled && !subs.some(s => s.playerId === playerId)) {
      const player = players.find(p => p.id === playerId)
      newSubs = [...subs, { id: uuid(), playerId, playerName: player?.name ?? 'Unknown', amount: subAmount, paid: false }]
    }
    save({ playerIds: newIds, driverIds: newDriverIds, subs: newSubs })
  }

  const toggleDriver = playerId => {
    if (!isAway || !playerIds.includes(playerId)) return
    const isDriver = driverIds.includes(playerId)
    const nextDriverIds = isDriver ? driverIds.filter(id => id !== playerId) : [...driverIds, playerId]
    let nextSubs = subs

    if (driversVoidSubs) {
      if (!isDriver) {
        nextSubs = subs.filter(sub => sub.playerId !== playerId)
      } else if (subsEnabled && !subs.some(sub => sub.playerId === playerId)) {
        const player = players.find(item => item.id === playerId)
        nextSubs = [...subs, { id: uuid(), playerId, playerName: player?.name ?? 'Unknown', amount: subAmount, paid: false }]
      }
    }

    save({ driverIds: nextDriverIds, subs: nextSubs })
  }

  const toggleSubPaid   = subId  => save({ subs: subs.map(s => s.id === subId ? { ...s, paid: !s.paid } : s) })
  const settleAllSubs   = ()     => save({ subs: subs.map(s => ({ ...s, paid: true })) })

  // ── Fines ─────────────────────────────────────────────────────────────────
  const handleAddFine = () => {
    const player   = players.find(p => p.id === newFine.playerId)
    const fineType = fineTypes.find(f => f.id === newFine.fineTypeId)
    if (!player || !fineType) return
    save({ fines: [...match.fines, { id: uuid(), playerId: player.id, playerName: player.name, fineTypeId: fineType.id, fineName: fineType.name, cost: fineType.cost, paid: false }] })
    setNewFine({ playerId: '', fineTypeId: '' })
    setShowAddFine(false)
  }

  const handleEditSave = () => {
    const player   = players.find(p => p.id === editFine.playerId)
    const fineType = fineTypes.find(f => f.id === editFine.fineTypeId)
    if (!player || !fineType) return
    save({ fines: match.fines.map(f => f.id === editFine.id ? { ...f, playerId: player.id, playerName: player.name, fineTypeId: fineType.id, fineName: fineType.name, cost: fineType.cost } : f) })
    setEditFine(null)
  }

  const togglePaid = fineId => save({ fines: match.fines.map(f => f.id === fineId ? { ...f, paid: !f.paid } : f) })

  const openPin   = action => { setPinAction(action); setPinInput(''); setPinError(''); setShowAdminPin(true) }
  const deleteFine = fineId => openPin({ type: 'deleteFine', fineId })

  const tryUnlock = async () => {
    const action = pinAction === 'unlock' ? APP_ACTION.UNLOCK_MATCH : pinAction === 'deleteMatch' ? APP_ACTION.DELETE_MATCH : APP_ACTION.DELETE_FINE_ENTRY
    const errorMessage = pinAction === 'unlock' ? 'Unlock code verification is required to unlock submitted matches.' : 'Unlock code verification is required for protected actions.'
    const allowed = await teamModel.canActorPerformProtectedAction({ action: action === APP_ACTION.UNLOCK_MATCH ? teamModel.PROTECTED_ACTION.UNLOCK_MATCH : action === APP_ACTION.DELETE_MATCH ? teamModel.PROTECTED_ACTION.DELETE_MATCH : teamModel.PROTECTED_ACTION.DELETE_FINE_ENTRY, membership, platformRole, teamId: currentTeamId, unlockCode: pinInput })
    if (!allowed) { setPinError(platformRole === 'admin' ? 'Platform admins cannot perform unlock-protected actions.' : 'Incorrect or unauthorized unlock code.'); return }
    if (pinAction === 'unlock') {
      await save({ submitted: false })
      await db.logProtectedRecordReversal({
        teamId: currentTeamId,
        actorMembership: membership,
        platformRole,
        entityType: 'match',
        entityId: match.id,
        payload: { matchDate: match.date, protectedAction: 'unlock_match' },
      })
    } else if (pinAction === 'deleteMatch') await onDelete()
    else if (pinAction?.type === 'deleteFine') {
      const deletedFine = match.fines.find(f => f.id === pinAction.fineId)
      await save({ fines: match.fines.filter(f => f.id !== pinAction.fineId) })
      await db.logProtectedRecordDeletion({
        teamId: currentTeamId,
        actorMembership: membership,
        platformRole,
        entityType: 'fine',
        entityId: pinAction.fineId,
        payload: {
          matchId: match.id,
          label: deletedFine?.fineName ?? null,
          playerId: deletedFine?.playerId ?? null,
          protectedAction: 'delete_fine_entry',
        },
      })
    }
    setShowAdminPin(false); setPinInput(''); setPinError(''); setPinAction(null)
  }

  // ── Totals ────────────────────────────────────────────────────────────────
  const finesTotal = match.fines.reduce((s, f) => s + f.cost, 0)
  const subsTotal  = subs.reduce((s, sub) => s + sub.amount, 0)

  const sections = [
    { key: 'fines',   label: `Fines (£${finesTotal.toFixed(2)})` },
    { key: 'players', label: `Players (${playerIds.length})` },
    { key: 'subs',    label: `Subs (£${subsTotal.toFixed(2)})` },
  ]

  return (
    <div>
      <div className="mb-3 rounded-xl border border-zinc-800 bg-zinc-900 px-1.5 py-3">
        <div className="flex items-start justify-between gap-3 px-1.5">
          <div className="min-w-0">
            <h2 className="font-display text-lg font-bold text-white">
              {formatDate(match.date)}{match.opponent ? ` vs ${match.opponent}` : ''} ({match.venue === 'away' ? 'Away' : 'Home'})
            </h2>
            {match.sourceCompetitionName && (
              <p className="mt-1 truncate text-xs font-semibold text-amber-300" title={match.sourceCompetitionName}>
                {match.sourceCompetitionName}
              </p>
            )}
          </div>
          {season && (
            <span className="max-w-[40%] shrink-0 truncate text-right font-display text-lg font-bold text-zinc-300">
              {season.name}
            </span>
          )}
        </div>
        <div className={`mt-4 ${TITLE_ACTION_GRID}`}>
          <TitleAction onClick={onBack}>← Back</TitleAction>
          {canCreateOrEdit && <TitleAction className="col-start-3" onClick={() => setShowAddFine(true)}>+ Add Fine</TitleAction>}
        </div>
      </div>

      <SegmentedControl
        className="mb-3"
        options={sections.map(({ key, label }) => ({ value: key, label }))}
        value={activeSection}
        onChange={setActiveSection}
        fullWidth
      />

      {/* Players */}
      {activeSection === 'players' && (
        <div className="mb-4">
          <div className="space-y-1.5">
            {[...players].sort((a, b) => a.name.localeCompare(b.name)).map(p => {
              const isIn = playerIds.includes(p.id)
              const isDriver = driverIds.includes(p.id)
              return (
                <div key={p.id} className={`flex items-center gap-2 rounded-xl border px-2 py-2 transition-all ${isIn ? 'border-amber-600 bg-amber-500/10' : 'border-zinc-700 bg-zinc-800'}`}>
                  <button
                    disabled={readonly || !canManageMatches}
                    onClick={() => togglePlayer(p.id)}
                    className={`flex min-w-0 flex-1 items-center justify-between gap-2 rounded-lg px-1 py-0.5 text-left ${readonly || !canManageMatches ? 'cursor-default opacity-75' : 'active:scale-[0.99]'}`}
                  >
                    <span className={`truncate text-sm font-medium ${isIn ? 'text-white' : 'text-zinc-400'}`}>{p.name}</span>
                    <span className={`shrink-0 rounded-full px-2 py-0.5 text-xs font-bold ${isIn ? 'bg-amber-500 text-zinc-900' : 'bg-zinc-700 text-zinc-500'}`}>{isIn ? 'Playing' : 'Not playing'}</span>
                  </button>
                  {isAway && isIn && (
                    <button
                      type="button"
                      disabled={readonly || !canManageMatches}
                      onClick={() => toggleDriver(p.id)}
                      className={`shrink-0 rounded-lg border px-2 py-1 text-xs font-bold transition-colors ${isDriver ? 'border-blue-500 bg-blue-600/30 text-blue-200' : 'border-zinc-600 bg-zinc-800 text-zinc-400 hover:text-white'} disabled:opacity-60`}
                    >
                      Driver
                    </button>
                  )}
                </div>
              )
            })}
            {!players.length && <p className="text-zinc-500 text-sm text-center py-4">No players set up yet</p>}
          </div>
        </div>
      )}

      {/* Fines */}
      {activeSection === 'fines' && (
        <div className="mb-4">
          <div className="space-y-2">
            {match.fines.map(f => (
              <div key={f.id} className={`flex items-center gap-3 rounded-xl px-3 py-2.5 border ${f.paid ? 'bg-emerald-950/40 border-emerald-800/50' : 'bg-zinc-800 border-zinc-700'}`}>
                <div className="flex-1 min-w-0">
                  <div className="font-medium text-white text-sm truncate">{f.playerName}</div>
                  <div className="text-zinc-400 text-xs">{f.fineName} · <span className="text-amber-400 font-bold">£{f.cost.toFixed(2)}</span></div>
                </div>
                <div className="flex items-center gap-1.5 shrink-0">
                  {f.paid ? <Badge color="green">Paid</Badge> : <Badge color="red">Owed</Badge>}
                  {canCreateOrEdit && (
                    <>
                      <button onClick={() => togglePaid(f.id)} className="text-xs px-2 py-1 rounded-lg bg-zinc-700 hover:bg-zinc-600 text-zinc-300">{f.paid ? 'U' : 'P'}</button>
                      <button onClick={() => setEditFine({ ...f })} className="text-xs px-2 py-1 rounded-lg bg-zinc-700 hover:bg-zinc-600 text-zinc-300">Ed</button>
                      <button onClick={() => deleteFine(f.id)} className="text-xs px-2 py-1 rounded-lg bg-red-900/50 hover:bg-red-800 text-red-300">Del</button>
                    </>
                  )}
                </div>
              </div>
            ))}
            {!match.fines.length && <p className="text-zinc-500 text-sm text-center py-6">No fines recorded yet</p>}
          </div>
        </div>
      )}

      {/* Subs */}
      {activeSection === 'subs' && (
        <div className="mb-4">
          {canCreateOrEdit && subs.some(s => !s.paid) && <div className="mb-2 flex justify-end"><Btn size="sm" variant="success" onClick={settleAllSubs}>Settle All Subs</Btn></div>}
          {!subsEnabled && <p className="text-zinc-500 text-sm text-center py-6">Subs are disabled for this team</p>}
          {subsEnabled && !subs.length && <p className="text-zinc-500 text-sm text-center py-6">No players selected yet</p>}
          <div className="space-y-2">
            {[...subs].sort((a, b) => a.playerName.localeCompare(b.playerName)).map(s => (
              <div key={s.id} className={`flex items-center gap-3 rounded-xl px-3 py-2.5 border ${s.paid ? 'bg-emerald-950/40 border-emerald-800/50' : 'bg-zinc-800 border-zinc-700'}`}>
                <div className="flex-1 min-w-0">
                  <div className="font-medium text-white text-sm">{s.playerName}</div>
                  <div className="text-zinc-400 text-xs">Sub · <span className="text-blue-400 font-bold">£{s.amount.toFixed(2)}</span></div>
                </div>
                <div className="flex items-center gap-1.5 shrink-0">
                  {s.paid ? <Badge color="green">Paid</Badge> : <Badge color="red">Owed</Badge>}
                  {canCreateOrEdit && (
                    <button onClick={() => toggleSubPaid(s.id)}
                      className={`text-xs px-2.5 py-1.5 rounded-lg font-bold transition-all ${s.paid ? 'bg-zinc-700 hover:bg-zinc-600 text-zinc-300' : 'bg-emerald-700 hover:bg-emerald-600 text-white'}`}>
                      {s.paid ? '↩' : '✓'}
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Actions */}
      <div className={`border-t border-zinc-700 pt-4 ${TITLE_ACTION_GRID}`}>
        {!readonly ? (
          <>
            {canManageMatches && <TitleAction onClick={() => setShowConfirmSubmit(true)}>Submit</TitleAction>}
            {canManageMatches && <TitleAction className="col-start-3" onClick={() => openPin('deleteMatch')}>Delete</TitleAction>}
          </>
        ) : (
          <TitleAction onClick={() => openPin('unlock')} disabled={!canUnlockMatch}>Unlock</TitleAction>
        )}
      </div>

      {/* Submit confirm */}
      {showConfirmSubmit && (
        <Modal title="Submit Match" onClose={() => setShowConfirmSubmit(false)}>
          <p className="text-zinc-300 text-sm mb-4">Once submitted this match becomes <strong className="text-white">read-only</strong>. Use Admin Unlock to make further changes.</p>
          <div className="flex gap-2">
            <Btn variant="success" className="flex-1" onClick={() => { save({ submitted: true }); setShowConfirmSubmit(false) }}>Confirm Submit</Btn>
            <Btn variant="ghost" className="flex-1" onClick={() => setShowConfirmSubmit(false)}>Cancel</Btn>
          </div>
        </Modal>
      )}

      {/* Add fine */}
      {showAddFine && (
        <Modal title="Add Fine" onClose={() => setShowAddFine(false)}>
          <Sel label="Player" value={newFine.playerId} onChange={e => setNewFine(n => ({ ...n, playerId: e.target.value }))}>
            <option value="">Select Player</option>
            {[...players].sort((a, b) => a.name.localeCompare(b.name)).map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
          </Sel>
          <Sel label="Fine" value={newFine.fineTypeId} onChange={e => setNewFine(n => ({ ...n, fineTypeId: e.target.value }))}>
            <option value="">Select Fine</option>
            {[...fineTypes].sort((a, b) => a.cost - b.cost || a.name.localeCompare(b.name)).map(f => <option key={f.id} value={f.id}>{f.name} (£{f.cost.toFixed(2)})</option>)}
          </Sel>
          <div className="flex gap-2 mt-2">
            <Btn onClick={handleAddFine} className="flex-1">Add Fine</Btn>
            <Btn variant="ghost" onClick={() => setShowAddFine(false)} className="flex-1">Cancel</Btn>
          </div>
        </Modal>
      )}

      {/* Edit fine */}
      {editFine && (
        <Modal title="Edit Fine" onClose={() => setEditFine(null)}>
          <Sel label="Player" value={editFine.playerId} onChange={e => setEditFine(f => ({ ...f, playerId: e.target.value }))}>
            <option value="">Select Player</option>
            {[...players].sort((a, b) => a.name.localeCompare(b.name)).map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
          </Sel>
          <Sel label="Fine" value={editFine.fineTypeId} onChange={e => setEditFine(f => ({ ...f, fineTypeId: e.target.value }))}>
            <option value="">Select Fine</option>
            {[...fineTypes].sort((a, b) => a.cost - b.cost || a.name.localeCompare(b.name)).map(f => <option key={f.id} value={f.id}>{f.name} (£{f.cost.toFixed(2)})</option>)}
          </Sel>
          <div className="flex gap-2 mt-2">
            <Btn onClick={handleEditSave} className="flex-1">Save Changes</Btn>
            <Btn variant="ghost" onClick={() => setEditFine(null)} className="flex-1">Cancel</Btn>
          </div>
        </Modal>
      )}

      {/* Admin PIN */}
      {showAdminPin && (
        <Modal title={pinAction === 'deleteMatch' ? 'Delete Match' : pinAction?.type === 'deleteFine' ? 'Delete Fine' : 'Admin Unlock'}
          onClose={() => { setShowAdminPin(false); setPinAction(null); setPinInput(''); setPinError('') }}>
          <p className="text-zinc-400 text-sm mb-4">
            {pinAction === 'deleteMatch' && 'Enter the team unlock code to permanently delete this match.'}
            {pinAction?.type === 'deleteFine' && 'Enter the team unlock code to delete this fine.'}
            {pinAction === 'unlock' && 'Enter the team unlock code to unlock this match for editing.'}
          </p>
          {(pinAction === 'deleteMatch' || pinAction?.type === 'deleteFine') && (
            <div className="bg-red-950/50 border border-red-800/50 rounded-lg px-3 py-2 mb-3 text-red-300 text-xs font-medium">Warning: cannot be undone.</div>
          )}
          <Input label="Team unlock code" type="password" value={pinInput} onChange={e => setPinInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && tryUnlock()} placeholder="Enter unlock code" />
          {pinError && <p className="text-red-400 text-sm mb-2">{pinError}</p>}
          <div className="flex gap-2">
            <Btn onClick={tryUnlock} variant={pinAction === 'deleteMatch' || pinAction?.type === 'deleteFine' ? 'danger' : 'primary'} className="flex-1">
              {pinAction === 'deleteMatch' ? 'Delete Match' : pinAction?.type === 'deleteFine' ? 'Delete Fine' : 'Unlock'}
            </Btn>
            <Btn variant="ghost" onClick={() => { setShowAdminPin(false); setPinAction(null); setPinInput(''); setPinError('') }} className="flex-1">Cancel</Btn>
          </div>
        </Modal>
      )}
    </div>
  )
}

// ─── Matches Tab ──────────────────────────────────────────────────────────────
function MatchCardPill({ children, color }) {
  const colors = {
    green: 'bg-emerald-900/60 text-emerald-300 border-emerald-700',
    amber: 'bg-amber-900/60 text-amber-300 border-amber-700',
    blue: 'bg-blue-900/60 text-blue-300 border-blue-700',
  }

  return (
    <span
      title={typeof children === 'string' ? children : undefined}
      className={`inline-flex min-h-7 w-28 shrink-0 items-center justify-center rounded border px-2 text-xs font-bold ${colors[color]}`}
    >
      <span className="truncate">{children}</span>
    </span>
  )
}

export default function MatchesTab({ players, fineTypes, seasons, matches, setMatches, withSave, currentTeamId, membership, platformRole, preferredSeasonId = 'all', onSeasonPreferenceChange }) {
  const [selectedId, setSelectedId] = useState(null)
  const [showNew,    setShowNew]    = useState(false)
  const [showStatusPicker, setShowStatusPicker] = useState(false)
  const [showSeasonPicker, setShowSeasonPicker] = useState(false)
  const [seasonFilter, setSeasonFilter] = useState(preferredSeasonId)
  const [statusFilter, setStatusFilter] = useState('draft')
  const [newMatch,   setNewMatch]   = useState({ date: '', seasonId: '', opponent: '', venue: 'home' })
  const canManageMatches = canAccessAction({ action: APP_ACTION.CREATE_MATCH, membership, platformRole })

  useEffect(() => {
    const isAvailable = preferredSeasonId === 'all' || seasons.some(season => season.id === preferredSeasonId)
    setSeasonFilter(isAvailable ? preferredSeasonId : 'all')
    if (!isAvailable) onSeasonPreferenceChange?.('all')
  }, [preferredSeasonId, seasons, onSeasonPreferenceChange])

  const selectedSeasonLabel = seasonFilter === 'all'
    ? 'All seasons'
    : seasons.find(season => season.id === seasonFilter)?.name ?? 'All seasons'
  const statusOptions = [
    { id: 'draft', name: 'Draft' },
    { id: 'submitted', name: 'Submitted' },
    { id: 'all', name: 'All matches' },
  ]
  const selectedStatusLabel = statusOptions.find(option => option.id === statusFilter)?.name ?? 'Draft'

  const filteredMatches = matches
    .filter(match => seasonFilter === 'all' || match.seasonId === seasonFilter)
    .filter(match => (
      statusFilter === 'all'
      || (statusFilter === 'submitted' ? match.submitted : !match.submitted)
    ))
    .sort((a, b) => a.date.localeCompare(b.date))

  const selectSeason = (seasonId) => {
    setSeasonFilter(seasonId)
    setShowSeasonPicker(false)
    onSeasonPreferenceChange?.(seasonId)
  }

  const createMatch = () => withSave(async () => {
    if (!newMatch.date) return
    const m = { id: uuid(), date: newMatch.date, seasonId: newMatch.seasonId, opponent: newMatch.opponent.trim(), venue: newMatch.venue, submitted: false, fines: [], playerIds: [], driverIds: [], subs: [] }
    if (!canManageMatches) throw new Error('You do not have permission to create matches.')
    await db.addMatch({ ...m, teamId: currentTeamId })
    setMatches(prev => [m, ...prev])
    setNewMatch({ date: '', seasonId: '', opponent: '', venue: 'home' })
    setShowNew(false)
    setSelectedId(m.id)
  })

  const updateMatch = (id, patch) => withSave(async () => {
    const current = matches.find(m => m.id === id)
    if (!current) return

    const updatedMatch = { ...current, ...patch }
    if (!canManageMatches) throw new Error('You do not have permission to update matches.')
    await db.updateMatch({ ...updatedMatch, teamId: currentTeamId })
    setMatches(prev => prev.map(m => m.id === id ? updatedMatch : m))
  })

  const deleteMatch = id => withSave(async () => {
    throw new Error('Use the protected unlock flow to delete matches.')
    setMatches(prev => prev.filter(m => m.id !== id))
    setSelectedId(null)
  })

  const currentMatch = matches.find(m => m.id === selectedId)

  if (selectedId && currentMatch) {
    return (
      <MatchDetail match={currentMatch} players={players} fineTypes={fineTypes} seasons={seasons} team={membership?.team} membership={membership} platformRole={platformRole} currentTeamId={currentTeamId}
        onBack={() => setSelectedId(null)}
        onSave={updateMatch}
        onDelete={() => db.deleteMatchWithAudit({ id: currentMatch.id, teamId: currentTeamId, actorMembership: membership, platformRole, matchDate: currentMatch.date }).then(() => { setMatches(prev => prev.filter(m => m.id !== currentMatch.id)); setSelectedId(null) })}
      />
    )
  }

  return (
    <div>
      <div className="mb-4 rounded-xl border border-zinc-800 bg-zinc-900 px-1.5 py-3">
        <h2 className="px-1.5 text-lg font-bold text-white">Match Log</h2>
        <div className={`mt-3 ${TITLE_ACTION_GRID}`}>
          <TitleAction onClick={() => setShowNew(true)} disabled={!canManageMatches}>New match</TitleAction>
          <button
            type="button"
            onClick={() => setShowStatusPicker(true)}
            aria-haspopup="dialog"
            aria-expanded={showStatusPicker}
            className={`col-start-2 inline-flex ${TITLE_ACTION_SIZE} items-center justify-center gap-2 border border-zinc-600 bg-zinc-800 px-3 py-2 text-xs font-bold leading-tight text-zinc-200 transition-colors hover:border-zinc-500 hover:bg-zinc-700 focus:outline-none focus:ring-2 focus:ring-amber-400`}
          >
            <span className="min-w-0 truncate">{selectedStatusLabel}</span>
            <span aria-hidden="true" className="text-zinc-400">⌄</span>
          </button>
          <button
            type="button"
            onClick={() => setShowSeasonPicker(true)}
            aria-haspopup="dialog"
            aria-expanded={showSeasonPicker}
            className={`col-start-3 inline-flex ${TITLE_ACTION_SIZE} items-center justify-center gap-2 border border-zinc-600 bg-zinc-800 px-3 py-2 text-xs font-bold leading-tight text-zinc-200 transition-colors hover:border-zinc-500 hover:bg-zinc-700 focus:outline-none focus:ring-2 focus:ring-amber-400`}
          >
            <span className="min-w-0 truncate">{selectedSeasonLabel}</span>
            <span aria-hidden="true" className="text-zinc-400">⌄</span>
          </button>
        </div>
      </div>

      <div className="space-y-2">
        {filteredMatches.map(m => {
          const season = seasons.find(s => s.id === m.seasonId)
          const total  = (m.fines ?? []).reduce((s, f) => s + f.cost, 0) + (m.subs ?? []).reduce((s, sub) => s + sub.amount, 0)
          const paid   = (m.fines ?? []).filter(f => f.paid).reduce((s, f) => s + f.cost, 0) + (m.subs ?? []).filter(s => s.paid).reduce((s, sub) => s + sub.amount, 0)
          return (
            <button key={m.id} onClick={() => setSelectedId(m.id)}
              className="w-full text-left bg-zinc-800 border border-zinc-700 rounded-xl px-4 py-3 hover:border-amber-600 transition-all active:scale-[0.99]">
              <div className="flex items-start justify-between gap-3">
                <span className="min-w-0 font-bold text-white">
                  {formatDate(m.date)}{m.opponent ? ` - vs ${m.opponent}` : ''} ({m.venue === 'away' ? 'Away' : 'Home'})
                </span>
                {m.submitted ? <MatchCardPill color="green">Submitted</MatchCardPill> : <MatchCardPill color="amber">Draft</MatchCardPill>}
              </div>
              {m.sourceCompetitionName && (
                <p className="mt-1 truncate text-xs font-semibold text-amber-300" title={m.sourceCompetitionName}>
                  {m.sourceCompetitionName}
                </p>
              )}
              <div className="mt-2 flex items-center justify-between gap-3 text-xs text-zinc-400">
                <span>
                  <span className="text-amber-400 font-bold">£{total.toFixed(2)}</span>
                  {' · '}
                  <span className="text-red-400">£{(total - paid).toFixed(2)} owed</span>
                </span>
                {season && <MatchCardPill color={season.type === 'Cup' ? 'amber' : 'blue'}>{season.name}</MatchCardPill>}
              </div>
            </button>
          )
        })}
        {!filteredMatches.length && (
          <p className="text-zinc-500 text-sm text-center py-12">
            {statusFilter === 'draft'
              ? 'No draft matches found.'
              : statusFilter === 'submitted'
                ? 'No submitted matches found.'
                : seasonFilter === 'all'
                  ? 'No matches yet. Create your first match to get started.'
                  : `No matches found for ${selectedSeasonLabel}.`}
          </p>
        )}
      </div>

      {showStatusPicker && (
        <Modal title="Select match status" onClose={() => setShowStatusPicker(false)}>
          <div className="space-y-2" role="radiogroup" aria-label="Match status">
            {statusOptions.map(option => {
              const isSelected = option.id === statusFilter
              return (
                <button
                  key={option.id}
                  type="button"
                  role="radio"
                  aria-checked={isSelected}
                  onClick={() => {
                    setStatusFilter(option.id)
                    setShowStatusPicker(false)
                  }}
                  className={[
                    'flex min-h-12 w-full items-center justify-between rounded-xl border px-4 py-3 text-left text-sm font-bold transition-colors',
                    isSelected
                      ? 'border-amber-400 bg-amber-500 text-zinc-950'
                      : 'border-zinc-700 bg-zinc-800 text-zinc-200 hover:border-zinc-600 hover:bg-zinc-700',
                  ].join(' ')}
                >
                  <span>{option.name}</span>
                  <span aria-hidden="true">{isSelected ? '✓' : ''}</span>
                </button>
              )
            })}
          </div>
        </Modal>
      )}

      {showSeasonPicker && (
        <Modal title="Select season" onClose={() => setShowSeasonPicker(false)}>
          <div className="space-y-2" role="radiogroup" aria-label="Matches season">
            {[{ id: 'all', name: 'All seasons' }, ...seasons].map(season => {
              const isSelected = season.id === seasonFilter
              return (
                <button
                  key={season.id}
                  type="button"
                  role="radio"
                  aria-checked={isSelected}
                  onClick={() => selectSeason(season.id)}
                  className={[
                    'flex min-h-12 w-full items-center justify-between rounded-xl border px-4 py-3 text-left text-sm font-bold transition-colors',
                    isSelected
                      ? 'border-amber-400 bg-amber-500 text-zinc-950'
                      : 'border-zinc-700 bg-zinc-800 text-zinc-200 hover:border-zinc-600 hover:bg-zinc-700',
                  ].join(' ')}
                >
                  <span>{season.name}</span>
                  <span aria-hidden="true">{isSelected ? '✓' : ''}</span>
                </button>
              )
            })}
          </div>
        </Modal>
      )}

      {showNew && (
        <Modal title="New Match" onClose={() => setShowNew(false)}>
          <Input label="Date" type="date" value={newMatch.date} onChange={e => setNewMatch(n => ({ ...n, date: e.target.value }))} />
          <Input label="Opponent (optional)" value={newMatch.opponent} onChange={e => setNewMatch(n => ({ ...n, opponent: e.target.value }))} placeholder="e.g. Red Lion" />
          <Sel label="Home or away" value={newMatch.venue} onChange={e => setNewMatch(n => ({ ...n, venue: e.target.value }))}>
            <option value="home">Home</option>
            <option value="away">Away</option>
          </Sel>
          <Sel label="Season (optional)" value={newMatch.seasonId} onChange={e => setNewMatch(n => ({ ...n, seasonId: e.target.value }))}>
            <option value="">No Season</option>
            {[...seasons].sort((a, b) => a.name.localeCompare(b.name)).map(s => <option key={s.id} value={s.id}>{s.name} · {s.type}</option>)}
          </Sel>
          <div className="flex gap-2 mt-2">
            <Btn onClick={createMatch} className="flex-1">Create Match</Btn>
            <Btn variant="ghost" onClick={() => setShowNew(false)} className="flex-1">Cancel</Btn>
          </div>
        </Modal>
      )}
    </div>
  )
}
