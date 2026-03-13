import { useState } from 'react'
import { Badge, Modal, Input, Sel, Btn, ADMIN_PIN, SUB_AMOUNT, uuid, formatDate } from '../App'
import * as db from '../lib/db'

// ─── Match Detail ─────────────────────────────────────────────────────────────
function MatchDetail({ match, players, fineTypes, seasons, onBack, onSave, onDelete }) {
  const [showAddFine,       setShowAddFine]       = useState(false)
  const [editFine,          setEditFine]           = useState(null)
  const [showAdminPin,      setShowAdminPin]       = useState(false)
  const [pinAction,         setPinAction]          = useState(null)
  const [pinInput,          setPinInput]           = useState('')
  const [pinError,          setPinError]           = useState('')
  const [newFine,           setNewFine]            = useState({ playerId: '', fineTypeId: '' })
  const [activeSection,     setActiveSection]      = useState('players')
  const [showConfirmSubmit, setShowConfirmSubmit]  = useState(false)

  const season    = seasons.find(s => s.id === match.seasonId)
  const readonly  = match.submitted
  const playerIds = match.playerIds ?? []
  const subs      = match.subs      ?? []

  const save = patch => onSave(match.id, patch)

  // ── Players ───────────────────────────────────────────────────────────────
  const togglePlayer = playerId => {
    const isIn    = playerIds.includes(playerId)
    const newIds  = isIn ? playerIds.filter(id => id !== playerId) : [...playerIds, playerId]
    let newSubs   = subs
    if (isIn) {
      newSubs = subs.filter(s => s.playerId !== playerId)
    } else if (!subs.some(s => s.playerId === playerId)) {
      const player = players.find(p => p.id === playerId)
      newSubs = [...subs, { id: uuid(), playerId, playerName: player?.name ?? 'Unknown', amount: SUB_AMOUNT, paid: false }]
    }
    save({ playerIds: newIds, subs: newSubs })
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

  const tryUnlock = () => {
    if (pinInput !== ADMIN_PIN) { setPinError('Incorrect PIN'); return }
    if (pinAction === 'unlock')           save({ submitted: false })
    else if (pinAction === 'deleteMatch') onDelete()
    else if (pinAction?.type === 'deleteFine') save({ fines: match.fines.filter(f => f.id !== pinAction.fineId) })
    setShowAdminPin(false); setPinInput(''); setPinError(''); setPinAction(null)
  }

  // ── Totals ────────────────────────────────────────────────────────────────
  const finesTotal = match.fines.reduce((s, f) => s + f.cost, 0)
  const finesPaid  = match.fines.filter(f => f.paid).reduce((s, f) => s + f.cost, 0)
  const subsTotal  = subs.reduce((s, sub) => s + sub.amount, 0)
  const subsPaid   = subs.filter(s => s.paid).reduce((s, sub) => s + sub.amount, 0)
  const grandTotal = finesTotal + subsTotal
  const grandPaid  = finesPaid + subsPaid
  const grandOwed  = grandTotal - grandPaid

  const sections = [
    { key: 'players', label: `Players (${playerIds.length})` },
    { key: 'fines',   label: `Fines (${match.fines.length})` },
    { key: 'subs',    label: `Subs (${subs.length})` },
  ]

  return (
    <div>
      <div className="flex items-center gap-3 mb-4">
        <button onClick={onBack} className="text-amber-400 hover:text-amber-300 font-bold text-sm">← Back</button>
        <div className="flex-1">
          <h2 className="font-display font-bold text-white text-lg">{formatDate(match.date)}</h2>
          {match.opponent && <p className="text-zinc-400 text-xs">vs {match.opponent}</p>}
        </div>
        {readonly ? <Badge color="green">Submitted</Badge> : <Badge color="amber">Draft</Badge>}
      </div>

      {season && <div className="mb-3"><Badge color={season.type === 'Cup' ? 'amber' : 'blue'}>{season.name} · {season.type}</Badge></div>}

      <div className="grid grid-cols-3 gap-2 mb-3">
        {[['Total', `£${grandTotal.toFixed(2)}`, 'text-white'], ['Paid', `£${grandPaid.toFixed(2)}`, 'text-emerald-400'], ['Owed', `£${grandOwed.toFixed(2)}`, 'text-red-400']].map(([l, v, c]) => (
          <div key={l} className="bg-zinc-800 rounded-xl p-3 text-center">
            <div className={`font-bold text-lg ${c}`}>{v}</div>
            <div className="text-zinc-500 text-xs">{l}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-2 gap-2 mb-4">
        <div className="bg-zinc-900 border border-zinc-700 rounded-xl px-3 py-2 flex justify-between items-center">
          <span className="text-zinc-400 text-xs">Fines</span>
          <span className="text-amber-400 font-bold text-sm">£{finesTotal.toFixed(2)}</span>
        </div>
        <div className="bg-zinc-900 border border-zinc-700 rounded-xl px-3 py-2 flex justify-between items-center">
          <span className="text-zinc-400 text-xs">Subs ({subs.length} × 50p)</span>
          <span className="text-blue-400 font-bold text-sm">£{subsTotal.toFixed(2)}</span>
        </div>
      </div>

      <div className="flex gap-1 mb-3 bg-zinc-800 rounded-xl p-1">
        {sections.map(({ key, label }) => (
          <button key={key} onClick={() => setActiveSection(key)}
            className={`flex-1 py-2 rounded-lg text-xs font-bold transition-all ${activeSection === key ? 'bg-amber-500 text-zinc-900' : 'text-zinc-400 hover:text-white'}`}>
            {label}
          </button>
        ))}
      </div>

      {/* Players */}
      {activeSection === 'players' && (
        <div className="mb-4">
          <p className="text-zinc-500 text-xs mb-2">{readonly ? 'Players who played in this match' : 'Tap to toggle. Each adds a 50p sub.'}</p>
          <div className="space-y-1.5">
            {[...players].sort((a, b) => a.name.localeCompare(b.name)).map(p => {
              const isIn = playerIds.includes(p.id)
              return (
                <button key={p.id} disabled={readonly} onClick={() => togglePlayer(p.id)}
                  className={`w-full flex items-center justify-between px-3 py-2.5 rounded-xl border transition-all text-left ${isIn ? 'bg-amber-500/10 border-amber-600 text-white' : 'bg-zinc-800 border-zinc-700 text-zinc-400'} ${readonly ? 'opacity-75 cursor-default' : 'hover:border-amber-500 active:scale-[0.99]'}`}>
                  <span className="font-medium text-sm">{p.name}</span>
                  <span className={`text-xs font-bold px-2 py-0.5 rounded-full ${isIn ? 'bg-amber-500 text-zinc-900' : 'bg-zinc-700 text-zinc-500'}`}>{isIn ? 'Playing' : 'Not playing'}</span>
                </button>
              )
            })}
            {!players.length && <p className="text-zinc-500 text-sm text-center py-4">No players set up yet</p>}
          </div>
        </div>
      )}

      {/* Fines */}
      {activeSection === 'fines' && (
        <div className="mb-4">
          {!readonly && <div className="flex justify-end mb-2"><Btn size="sm" onClick={() => setShowAddFine(true)}>+ Add Fine</Btn></div>}
          <div className="space-y-2">
            {match.fines.map(f => (
              <div key={f.id} className={`flex items-center gap-3 rounded-xl px-3 py-2.5 border ${f.paid ? 'bg-emerald-950/40 border-emerald-800/50' : 'bg-zinc-800 border-zinc-700'}`}>
                <div className="flex-1 min-w-0">
                  <div className="font-medium text-white text-sm truncate">{f.playerName}</div>
                  <div className="text-zinc-400 text-xs">{f.fineName} · <span className="text-amber-400 font-bold">£{f.cost.toFixed(2)}</span></div>
                </div>
                <div className="flex items-center gap-1.5 shrink-0">
                  {f.paid ? <Badge color="green">Paid</Badge> : <Badge color="red">Owed</Badge>}
                  {!readonly && (
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
          <div className="flex items-center justify-between mb-2">
            <p className="text-zinc-500 text-xs">50p per player per match</p>
            {!readonly && subs.some(s => !s.paid) && <Btn size="sm" variant="success" onClick={settleAllSubs}>Settle All Subs</Btn>}
          </div>
          {!subs.length && <p className="text-zinc-500 text-sm text-center py-6">No players selected yet</p>}
          <div className="space-y-2">
            {[...subs].sort((a, b) => a.playerName.localeCompare(b.playerName)).map(s => (
              <div key={s.id} className={`flex items-center gap-3 rounded-xl px-3 py-2.5 border ${s.paid ? 'bg-emerald-950/40 border-emerald-800/50' : 'bg-zinc-800 border-zinc-700'}`}>
                <div className="flex-1 min-w-0">
                  <div className="font-medium text-white text-sm">{s.playerName}</div>
                  <div className="text-zinc-400 text-xs">Sub · <span className="text-blue-400 font-bold">£{s.amount.toFixed(2)}</span></div>
                </div>
                <div className="flex items-center gap-1.5 shrink-0">
                  {s.paid ? <Badge color="green">Paid</Badge> : <Badge color="red">Owed</Badge>}
                  {!readonly && (
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
      <div className="border-t border-zinc-700 pt-4 space-y-2">
        {!readonly ? (
          <>
            <Btn variant="success" className="w-full" onClick={() => setShowConfirmSubmit(true)}>Submit Match</Btn>
            <Btn variant="danger"  className="w-full" onClick={() => openPin('deleteMatch')}>Delete Match</Btn>
          </>
        ) : (
          <Btn variant="outline" className="w-full" onClick={() => openPin('unlock')}>Admin Unlock</Btn>
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
            {pinAction === 'deleteMatch' && 'Enter admin PIN to permanently delete this match.'}
            {pinAction?.type === 'deleteFine' && 'Enter admin PIN to delete this fine.'}
            {pinAction === 'unlock' && 'Enter admin PIN to unlock this match for editing.'}
          </p>
          {(pinAction === 'deleteMatch' || pinAction?.type === 'deleteFine') && (
            <div className="bg-red-950/50 border border-red-800/50 rounded-lg px-3 py-2 mb-3 text-red-300 text-xs font-medium">Warning: cannot be undone.</div>
          )}
          <Input label="Admin PIN" type="password" value={pinInput} onChange={e => setPinInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && tryUnlock()} placeholder="Enter PIN" />
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
export default function MatchesTab({ players, fineTypes, seasons, matches, setMatches, withSave }) {
  const [selectedId, setSelectedId] = useState(null)
  const [showNew,    setShowNew]    = useState(false)
  const [newMatch,   setNewMatch]   = useState({ date: '', seasonId: '', opponent: '' })

  const createMatch = () => withSave(async () => {
    if (!newMatch.date) return
    const m = { id: uuid(), date: newMatch.date, seasonId: newMatch.seasonId, opponent: newMatch.opponent.trim(), submitted: false, fines: [], playerIds: [], subs: [] }
    await db.addMatch(m)
    setMatches(prev => [m, ...prev])
    setNewMatch({ date: '', seasonId: '', opponent: '' })
    setShowNew(false)
    setSelectedId(m.id)
  })

  const updateMatch = (id, patch) => withSave(async () => {
    const previous = matches
    const next = previous.map(m => m.id === id ? { ...m, ...patch } : m)
    const updated = next.find(m => m.id === id)
    if (!updated) return

    setMatches(next)
    try {
      await db.updateMatch(updated)
    } catch (err) {
      setMatches(previous)
      throw err
    }
  })

  const deleteMatch = id => withSave(async () => {
    await db.deleteMatch(id)
    setMatches(prev => prev.filter(m => m.id !== id))
    setSelectedId(null)
  })

  const currentMatch = matches.find(m => m.id === selectedId)

  if (selectedId && currentMatch) {
    return (
      <MatchDetail match={currentMatch} players={players} fineTypes={fineTypes} seasons={seasons}
        onBack={() => setSelectedId(null)}
        onSave={updateMatch}
        onDelete={() => deleteMatch(currentMatch.id)}
      />
    )
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h2 className="font-display text-lg font-bold text-white">Matches</h2>
        <Btn onClick={() => setShowNew(true)}>+ New Match</Btn>
      </div>

      <div className="space-y-2">
        {[...matches].sort((a, b) => b.date.localeCompare(a.date)).map(m => {
          const season = seasons.find(s => s.id === m.seasonId)
          const total  = (m.fines ?? []).reduce((s, f) => s + f.cost, 0) + (m.subs ?? []).reduce((s, sub) => s + sub.amount, 0)
          const paid   = (m.fines ?? []).filter(f => f.paid).reduce((s, f) => s + f.cost, 0) + (m.subs ?? []).filter(s => s.paid).reduce((s, sub) => s + sub.amount, 0)
          return (
            <button key={m.id} onClick={() => setSelectedId(m.id)}
              className="w-full text-left bg-zinc-800 border border-zinc-700 rounded-xl px-4 py-3 hover:border-amber-600 transition-all active:scale-[0.99]">
              <div className="flex items-center justify-between mb-1">
                <span className="font-bold text-white">{formatDate(m.date)}</span>
                {m.submitted ? <Badge color="green">Submitted</Badge> : <Badge color="amber">Draft</Badge>}
              </div>
              <div className="flex items-center gap-3 text-xs text-zinc-400">
                {m.opponent && <span>vs {m.opponent}</span>}
                {season && <Badge color={season.type === 'Cup' ? 'amber' : 'blue'}>{season.name}</Badge>}
                <span className="ml-auto">
                  <span className="text-amber-400 font-bold">£{total.toFixed(2)}</span>
                  {' · '}
                  <span className="text-red-400">£{(total - paid).toFixed(2)} owed</span>
                </span>
              </div>
            </button>
          )
        })}
        {!matches.length && <p className="text-zinc-500 text-sm text-center py-12">No matches yet — create one to get started</p>}
      </div>

      {showNew && (
        <Modal title="New Match" onClose={() => setShowNew(false)}>
          <Input label="Date" type="date" value={newMatch.date} onChange={e => setNewMatch(n => ({ ...n, date: e.target.value }))} />
          <Input label="Opponent (optional)" value={newMatch.opponent} onChange={e => setNewMatch(n => ({ ...n, opponent: e.target.value }))} placeholder="e.g. Red Lion" />
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
