import { useState } from 'react'
import { Badge, Modal, Input, Sel, Btn, TitleAction, SegmentedControl, TITLE_ACTION_GRID, TITLE_ACTION_SIZE, formatDate } from '../App'
import * as db from '../lib/db'
import * as teamModel from '../lib/teamModel'
import { APP_ACTION, canAccessAction } from '../lib/accessControl'

export default function FinesTab({ players, seasons, matches, setMatches, withSave, currentTeamId, membership, platformRole }) {
  const [filterSeason, setFilterSeason] = useState('all')
  const [filterPlayer, setFilterPlayer] = useState('all')
  const canManageFines = canAccessAction({ action: APP_ACTION.MANAGE_PAYMENTS, membership, platformRole })
  const [filterStatus, setFilterStatus] = useState('all')
  const [filterType,   setFilterType]   = useState('all')
  const [pendingDelete, setPendingDelete] = useState(null)
  const [showSettle, setShowSettle] = useState(false)
  const [settleSeason, setSettleSeason] = useState('all')
  const [pinInput,  setPinInput]  = useState('')
  const [pinError,  setPinError]  = useState('')

  const allFines = matches.flatMap(m => m.fines.map(f => ({ ...f, kind: 'fine', amount: f.cost, matchDate: m.date, matchId: m.id, seasonId: m.seasonId })))
  const allSubs  = matches.flatMap(m => (m.subs ?? []).map(s => ({ ...s, kind: 'sub', matchDate: m.date, matchId: m.id, seasonId: m.seasonId })))

  const allItems = [
    ...allFines.map(f => ({ id: f.id, matchId: f.matchId, seasonId: f.seasonId, kind: 'fine', playerId: f.playerId, playerName: f.playerName, label: f.fineName, amount: f.cost, paid: f.paid, matchDate: f.matchDate })),
    ...allSubs.map(s  => ({ id: s.id, matchId: s.matchId, seasonId: s.seasonId, kind: 'sub',  playerId: s.playerId, playerName: s.playerName, label: 'Sub',      amount: s.amount, paid: s.paid, matchDate: s.matchDate })),
  ].sort((a, b) => b.matchDate.localeCompare(a.matchDate) || a.playerName.localeCompare(b.playerName))

  const filtered = allItems.filter(item => {
    if (filterSeason !== 'all' && item.seasonId !== filterSeason) return false
    if (filterPlayer !== 'all' && item.playerId !== filterPlayer) return false
    if (filterStatus === 'paid'        && !item.paid) return false
    if (filterStatus === 'outstanding' &&  item.paid) return false
    if (filterType === 'fines' && item.kind !== 'fine') return false
    if (filterType === 'subs'  && item.kind !== 'sub')  return false
    return true
  })

  const totalAmt = filtered.reduce((s, i) => s + i.amount, 0)
  const paidAmt  = filtered.filter(i => i.paid).reduce((s, i) => s + i.amount, 0)
  const selectedPlayer = players.find(player => player.id === filterPlayer) ?? null

  const settlementItems = showSettle ? allItems.filter(item => {
    if (!selectedPlayer || item.playerId !== selectedPlayer.id) return false
    if (settleSeason !== 'all' && item.seasonId !== settleSeason) return false
    if (filterStatus === 'paid' && !item.paid) return false
    if (filterStatus === 'outstanding' && item.paid) return false
    if (filterType === 'fines' && item.kind !== 'fine') return false
    if (filterType === 'subs' && item.kind !== 'sub') return false
    return !item.paid
  }) : []
  const settlementTotal = settlementItems.reduce((sum, item) => sum + item.amount, 0)

  const openSettlement = () => {
    setSettleSeason(filterSeason)
    setShowSettle(true)
  }

  const settleFiltered = () => withSave(async () => {
    if (!canManageFines || !selectedPlayer || !settlementItems.length) return
    const fineIds = new Set(settlementItems.filter(item => item.kind === 'fine').map(item => item.id))
    const subIds = new Set(settlementItems.filter(item => item.kind === 'sub').map(item => item.id))
    const changedMatchIds = new Set(settlementItems.map(item => item.matchId))
    const updatedMatches = matches.map(match => changedMatchIds.has(match.id) ? {
      ...match,
      fines: match.fines.map(fine => fineIds.has(fine.id) ? { ...fine, paid: true } : fine),
      subs: (match.subs ?? []).map(sub => subIds.has(sub.id) ? { ...sub, paid: true } : sub),
    } : match)

    await Promise.all(updatedMatches.filter(match => changedMatchIds.has(match.id)).map(match => db.updateMatch({ ...match, teamId: currentTeamId })))
    setMatches(updatedMatches)
    setShowSettle(false)
  })

  const togglePaid = item => withSave(async () => {
    if (!canManageFines) throw new Error('You do not have permission to manage payments.')
    const currentMatch = matches.find(m => m.id === item.matchId)
    if (!currentMatch) return

    const updatedMatch = item.kind === 'fine'
      ? { ...currentMatch, fines: currentMatch.fines.map(f => f.id === item.id ? { ...f, paid: !f.paid } : f) }
      : { ...currentMatch, subs: (currentMatch.subs ?? []).map(s => s.id === item.id ? { ...s, paid: !s.paid } : s) }

    if (updatedMatch) await db.updateMatch({ ...updatedMatch, teamId: currentTeamId })
    setMatches(prev => prev.map(m => m.id === item.matchId ? updatedMatch : m))
  })

  const confirmDelete = () => withSave(async () => {
    if (!canManageFines) throw new Error('You do not have permission to manage payments.')
    const allowed = await teamModel.canActorPerformProtectedAction({ action: teamModel.PROTECTED_ACTION.DELETE_FINE_ENTRY, membership, platformRole, teamId: currentTeamId, unlockCode: pinInput })
    if (!allowed) { setPinError(platformRole === 'admin' ? 'Platform admins cannot perform unlock-protected actions.' : 'Incorrect or unauthorized unlock code.'); return }
    const item = pendingDelete
    if (!item) return

    const currentMatch = matches.find(m => m.id === item.matchId)
    if (!currentMatch) return

    const updatedMatch = item.kind === 'fine'
      ? { ...currentMatch, fines: currentMatch.fines.filter(f => f.id !== item.id) }
      : { ...currentMatch, subs: (currentMatch.subs ?? []).filter(s => s.id !== item.id) }

    if (updatedMatch) await db.updateMatch({ ...updatedMatch, teamId: currentTeamId })
    await db.logProtectedRecordDeletion({
      teamId: currentTeamId,
      actorMembership: membership,
      platformRole,
      entityType: item.kind === 'fine' ? 'fine' : 'sub',
      entityId: item.id,
      payload: {
        matchId: item.matchId,
        label: item.label,
        playerId: item.playerId,
        protectedAction: 'delete_fine_entry',
      },
    })
    setMatches(prev => prev.map(m => m.id === item.matchId ? updatedMatch : m))
    setPendingDelete(null); setPinInput(''); setPinError('')
  })

  return (
    <div>
      <div className="mb-4 rounded-xl border border-zinc-800 bg-zinc-900 px-1.5 py-3">
        <div className={TITLE_ACTION_GRID}>
          <h2 className="col-span-2 self-center px-1.5 text-lg font-bold text-white">Balances and payments</h2>
          {canManageFines && selectedPlayer && (
            <TitleAction onClick={openSettlement}>Settle All</TitleAction>
          )}
        </div>
        <div className={`mt-3 ${TITLE_ACTION_GRID}`}>
          <select
            value={filterSeason}
            onChange={event => setFilterSeason(event.target.value)}
            aria-label="Filter by season"
            className={`${TITLE_ACTION_SIZE} min-w-0 bg-zinc-800 border border-zinc-600 px-3 py-2 text-zinc-200 text-xs font-bold focus:outline-none focus:border-amber-500`}
          >
            <option value="all">All Seasons</option>
            {[...seasons].sort((a, b) => a.name.localeCompare(b.name)).map(season => <option key={season.id} value={season.id}>{season.name}</option>)}
          </select>
          <select
            value={filterStatus}
            onChange={event => setFilterStatus(event.target.value)}
            aria-label="Filter by payment status"
            className={`${TITLE_ACTION_SIZE} min-w-0 bg-zinc-800 border border-zinc-600 px-3 py-2 text-zinc-200 text-xs font-bold focus:outline-none focus:border-amber-500`}
          >
            <option value="all">All Status</option>
            <option value="paid">Paid</option>
            <option value="outstanding">Outstanding</option>
          </select>
          <select
            value={filterPlayer}
            onChange={event => setFilterPlayer(event.target.value)}
            aria-label="Filter by player"
            className={`${TITLE_ACTION_SIZE} min-w-0 bg-zinc-800 border border-zinc-600 px-3 py-2 text-zinc-200 text-xs font-bold focus:outline-none focus:border-amber-500`}
          >
            <option value="all">All Players</option>
            {[...players].sort((a, b) => a.name.localeCompare(b.name)).map(player => <option key={player.id} value={player.id}>{player.name}</option>)}
          </select>
        </div>
      </div>

      <SegmentedControl
        className="mb-3"
        options={[['all', 'All'], ['fines', 'Fines'], ['subs', 'Subs']].map(([value, label]) => ({ value, label }))}
        value={filterType}
        onChange={setFilterType}
        fullWidth
      />

      {/* Totals */}
      <div className="grid grid-cols-3 gap-2 mb-3">
        {[['Total', `£${totalAmt.toFixed(2)}`, 'text-white'], ['Paid', `£${paidAmt.toFixed(2)}`, 'text-emerald-400'], ['Owed', `£${(totalAmt - paidAmt).toFixed(2)}`, 'text-red-400']].map(([l, v, c]) => (
          <div key={l} className="bg-zinc-800 rounded-xl p-2.5 text-center">
            <div className={`font-bold text-base ${c}`}>{v}</div>
            <div className="text-zinc-500 text-xs">{l}</div>
          </div>
        ))}
      </div>

      {/* Items list */}
      <div className="space-y-2">
        {filtered.map(item => (
          <div key={`${item.matchId}-${item.id}`}
            className={`rounded-xl border px-3 py-2.5 ${item.paid ? 'bg-emerald-950/30 border-emerald-800/40' : 'bg-zinc-800 border-zinc-700'}`}>
            <div className="flex items-center justify-between gap-2">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="font-bold text-white text-sm">{item.playerName}</span>
                  <Badge color={item.kind === 'sub' ? 'blue' : 'gray'}>{item.kind === 'sub' ? 'Sub' : 'Fine'}</Badge>
                  <Badge color={item.paid ? 'green' : 'red'}>{item.paid ? 'Paid' : 'Owed'}</Badge>
                </div>
                <div className="text-zinc-400 text-xs mt-0.5">
                  {item.label} · <span className={`font-bold ${item.kind === 'sub' ? 'text-blue-400' : 'text-amber-400'}`}>£{item.amount.toFixed(2)}</span> · {formatDate(item.matchDate)}
                </div>
              </div>
              <div className="flex items-center gap-1.5 shrink-0">
                {canManageFines && <button onClick={() => togglePaid(item)}
                  className={`text-xs px-2.5 py-1.5 rounded-lg font-bold transition-all ${item.paid ? 'bg-zinc-700 hover:bg-zinc-600 text-zinc-300' : 'bg-emerald-700 hover:bg-emerald-600 text-white'}`}>
                  {item.paid ? 'Unpay' : 'Pay'}
                </button>}
                {canManageFines && <button onClick={() => { setPendingDelete(item); setPinInput(''); setPinError('') }}
                  className="text-xs px-2.5 py-1.5 rounded-lg font-bold bg-red-900/50 hover:bg-red-800 text-red-300 transition-all">
                  Delete
                </button>}
              </div>
            </div>
          </div>
        ))}
        {!filtered.length && <p className="text-zinc-500 text-sm text-center py-8">No balances match the current filter.</p>}
      </div>

      {/* Delete PIN modal */}
      {pendingDelete && (
        <Modal title={`Delete ${pendingDelete.kind === 'sub' ? 'Sub' : 'Fine'}`} onClose={() => { setPendingDelete(null); setPinInput(''); setPinError('') }}>
          <p className="text-zinc-400 text-sm mb-3">Delete <strong className="text-white">{pendingDelete.label}</strong> for <strong className="text-white">{pendingDelete.playerName}</strong>? Enter the team unlock code.</p>
          <div className="bg-red-950/50 border border-red-800/50 rounded-lg px-3 py-2 mb-3 text-red-300 text-xs font-medium">Warning: cannot be undone.</div>
          <Input label="Team unlock code" type="password" value={pinInput} onChange={e => setPinInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && confirmDelete()} placeholder="Enter unlock code" />
          {pinError && <p className="text-red-400 text-sm mb-2">{pinError}</p>}
          <div className="flex gap-2">
            <Btn variant="danger" className="flex-1" onClick={confirmDelete}>Delete</Btn>
            <Btn variant="ghost" className="flex-1" onClick={() => { setPendingDelete(null); setPinInput(''); setPinError('') }}>Cancel</Btn>
          </div>
        </Modal>
      )}

      {showSettle && selectedPlayer && (
        <Modal title={`Settle ${selectedPlayer.name}`} onClose={() => setShowSettle(false)}>
          <Sel label="Season" value={settleSeason} onChange={event => setSettleSeason(event.target.value)}>
            <option value="all">All Seasons</option>
            {[...seasons].sort((a, b) => a.name.localeCompare(b.name)).map(season => <option key={season.id} value={season.id}>{season.name}</option>)}
          </Sel>
          <div className="mb-4 rounded-xl border border-zinc-700 bg-zinc-800 p-3">
            <div className="flex items-center justify-between gap-3">
              <span className="text-sm text-zinc-400">Outstanding to settle</span>
              <span className="text-lg font-bold text-red-400">£{settlementTotal.toFixed(2)}</span>
            </div>
            <p className="mt-1 text-xs text-zinc-500">
              {settlementItems.length} {settlementItems.length === 1 ? 'entry' : 'entries'} matching the current status and type filters
            </p>
          </div>
          <div className="flex gap-2">
            <Btn variant="success" className="flex-1" onClick={settleFiltered} disabled={!settlementItems.length}>Settle</Btn>
            <Btn variant="ghost" className="flex-1" onClick={() => setShowSettle(false)}>Cancel</Btn>
          </div>
        </Modal>
      )}
    </div>
  )
}
