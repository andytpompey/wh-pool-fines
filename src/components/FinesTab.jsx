import { useState } from 'react'
import { Badge, Modal, Input, Btn, ADMIN_PIN, formatDate } from '../App'
import * as db from '../lib/db'

export default function FinesTab({ players, matches, setMatches, withSave }) {
  const [filterPlayer, setFilterPlayer] = useState('all')
  const [filterStatus, setFilterStatus] = useState('all')
  const [filterType,   setFilterType]   = useState('all')
  const [showSettle,   setShowSettle]   = useState(null)
  const [pendingDelete, setPendingDelete] = useState(null)
  const [pinInput,  setPinInput]  = useState('')
  const [pinError,  setPinError]  = useState('')

  const allFines = matches.flatMap(m => m.fines.map(f => ({ ...f, kind: 'fine', amount: f.cost, matchDate: m.date, matchId: m.id })))
  const allSubs  = matches.flatMap(m => (m.subs ?? []).map(s => ({ ...s, kind: 'sub', matchDate: m.date, matchId: m.id })))

  const allItems = [
    ...allFines.map(f => ({ id: f.id, matchId: f.matchId, kind: 'fine', playerId: f.playerId, playerName: f.playerName, label: f.fineName, amount: f.cost, paid: f.paid, matchDate: f.matchDate })),
    ...allSubs.map(s  => ({ id: s.id, matchId: s.matchId, kind: 'sub',  playerId: s.playerId, playerName: s.playerName, label: 'Sub',      amount: s.amount, paid: s.paid, matchDate: s.matchDate })),
  ].sort((a, b) => b.matchDate.localeCompare(a.matchDate) || a.playerName.localeCompare(b.playerName))

  const filtered = allItems.filter(item => {
    if (filterPlayer !== 'all' && item.playerId !== filterPlayer) return false
    if (filterStatus === 'paid'        && !item.paid) return false
    if (filterStatus === 'outstanding' &&  item.paid) return false
    if (filterType === 'fines' && item.kind !== 'fine') return false
    if (filterType === 'subs'  && item.kind !== 'sub')  return false
    return true
  })

  const totalAmt = filtered.reduce((s, i) => s + i.amount, 0)
  const paidAmt  = filtered.filter(i => i.paid).reduce((s, i) => s + i.amount, 0)

  const togglePaid = item => withSave(async () => {
    setMatches(prev => {
      const next = prev.map(m => {
        if (m.id !== item.matchId) return m
        if (item.kind === 'fine') return { ...m, fines: m.fines.map(f => f.id === item.id ? { ...f, paid: !f.paid } : f) }
        return { ...m, subs: (m.subs ?? []).map(s => s.id === item.id ? { ...s, paid: !s.paid } : s) }
      })
      const updatedMatch = next.find(m => m.id === item.matchId)
      db.updateMatch(updatedMatch)
      return next
    })
  })

  const settleAll = playerId => withSave(async () => {
    setMatches(prev => {
      const next = prev.map(m => ({
        ...m,
        fines: m.fines.map(f => f.playerId === playerId && !f.paid ? { ...f, paid: true } : f),
        subs:  (m.subs ?? []).map(s => s.playerId === playerId && !s.paid ? { ...s, paid: true } : s),
      }))
      next.forEach(m => db.updateMatch(m))
      return next
    })
    setShowSettle(null)
  })

  const confirmDelete = () => withSave(async () => {
    if (pinInput !== ADMIN_PIN) { setPinError('Incorrect PIN'); return }
    const item = pendingDelete
    setMatches(prev => {
      const next = prev.map(m => {
        if (m.id !== item.matchId) return m
        if (item.kind === 'fine') return { ...m, fines: m.fines.filter(f => f.id !== item.id) }
        return { ...m, subs: (m.subs ?? []).filter(s => s.id !== item.id) }
      })
      const updatedMatch = next.find(m => m.id === item.matchId)
      db.updateMatch(updatedMatch)
      return next
    })
    setPendingDelete(null); setPinInput(''); setPinError('')
  })

  const playerSummaries = [...players].sort((a, b) => a.name.localeCompare(b.name)).map(p => {
    const pf    = allFines.filter(f => f.playerId === p.id)
    const ps    = allSubs.filter(s => s.playerId === p.id)
    const fTot  = pf.reduce((s, f) => s + f.cost, 0)
    const fPaid = pf.filter(f => f.paid).reduce((s, f) => s + f.cost, 0)
    const sTot  = ps.reduce((s, sub) => s + sub.amount, 0)
    const sPaid = ps.filter(s => s.paid).reduce((s, sub) => s + sub.amount, 0)
    const total = fTot + sTot
    const paid  = fPaid + sPaid
    return { ...p, total, paid, outstanding: total - paid, count: pf.length, subCount: ps.length, finesOwed: fTot - fPaid, subsOwed: sTot - sPaid }
  }).filter(p => p.total > 0)

  return (
    <div>
      {/* Player balances */}
      {playerSummaries.length > 0 && (
        <div className="mb-5">
          <h3 className="font-bold text-zinc-400 text-xs uppercase tracking-wider mb-2">Player Balances</h3>
          <div className="space-y-2">
            {playerSummaries.map(p => (
              <div key={p.id} className="bg-zinc-800 border border-zinc-700 rounded-xl px-4 py-3 flex items-center justify-between">
                <div>
                  <div className="font-bold text-white text-sm">{p.name}</div>
                  <div className="text-xs text-zinc-400 mt-0.5">{p.count} fines · {p.subCount} subs · <span className="text-emerald-400">£{p.paid.toFixed(2)} paid</span></div>
                </div>
                <div className="flex items-center gap-2">
                  <div className="text-right">
                    <div className={`font-bold text-sm ${p.outstanding > 0 ? 'text-red-400' : 'text-emerald-400'}`}>£{p.outstanding.toFixed(2)}</div>
                    <div className="text-xs text-zinc-500">owed</div>
                  </div>
                  {p.outstanding > 0 && <Btn size="sm" variant="success" onClick={() => setShowSettle(p)}>Settle</Btn>}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="grid grid-cols-2 gap-2 mb-2">
        <select value={filterPlayer} onChange={e => setFilterPlayer(e.target.value)}
          className="bg-zinc-800 border border-zinc-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-amber-500">
          <option value="all">All Players</option>
          {[...players].sort((a, b) => a.name.localeCompare(b.name)).map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
        </select>
        <select value={filterStatus} onChange={e => setFilterStatus(e.target.value)}
          className="bg-zinc-800 border border-zinc-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-amber-500">
          <option value="all">All Status</option>
          <option value="paid">Paid</option>
          <option value="outstanding">Outstanding</option>
        </select>
      </div>
      <div className="flex gap-1 mb-4 bg-zinc-800 rounded-xl p-1">
        {[['all','All'],['fines','Fines'],['subs','Subs']].map(([v, label]) => (
          <button key={v} onClick={() => setFilterType(v)}
            className={`flex-1 py-1.5 rounded-lg text-xs font-bold transition-all ${filterType === v ? 'bg-amber-500 text-zinc-900' : 'text-zinc-400 hover:text-white'}`}>
            {label}
          </button>
        ))}
      </div>

      {/* Totals */}
      <div className="grid grid-cols-3 gap-2 mb-4">
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
                <button onClick={() => togglePaid(item)}
                  className={`text-xs px-2.5 py-1.5 rounded-lg font-bold transition-all ${item.paid ? 'bg-zinc-700 hover:bg-zinc-600 text-zinc-300' : 'bg-emerald-700 hover:bg-emerald-600 text-white'}`}>
                  {item.paid ? 'Unpay' : 'Pay'}
                </button>
                <button onClick={() => { setPendingDelete(item); setPinInput(''); setPinError('') }}
                  className="text-xs px-2.5 py-1.5 rounded-lg font-bold bg-red-900/50 hover:bg-red-800 text-red-300 transition-all">
                  Del
                </button>
              </div>
            </div>
          </div>
        ))}
        {!filtered.length && <p className="text-zinc-500 text-sm text-center py-8">No items match current filter</p>}
      </div>

      {/* Delete PIN modal */}
      {pendingDelete && (
        <Modal title={`Delete ${pendingDelete.kind === 'sub' ? 'Sub' : 'Fine'}`} onClose={() => { setPendingDelete(null); setPinInput(''); setPinError('') }}>
          <p className="text-zinc-400 text-sm mb-3">Delete <strong className="text-white">{pendingDelete.label}</strong> for <strong className="text-white">{pendingDelete.playerName}</strong>? Enter admin PIN.</p>
          <div className="bg-red-950/50 border border-red-800/50 rounded-lg px-3 py-2 mb-3 text-red-300 text-xs font-medium">Warning: cannot be undone.</div>
          <Input label="Admin PIN" type="password" value={pinInput} onChange={e => setPinInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && confirmDelete()} placeholder="Enter PIN" />
          {pinError && <p className="text-red-400 text-sm mb-2">{pinError}</p>}
          <div className="flex gap-2">
            <Btn variant="danger" className="flex-1" onClick={confirmDelete}>Delete</Btn>
            <Btn variant="ghost" className="flex-1" onClick={() => { setPendingDelete(null); setPinInput(''); setPinError('') }}>Cancel</Btn>
          </div>
        </Modal>
      )}

      {/* Settle modal */}
      {showSettle && (
        <Modal title={`Settle ${showSettle.name}`} onClose={() => setShowSettle(null)}>
          <p className="text-zinc-300 text-sm mb-4">Mark all outstanding fines and subs for <strong className="text-white">{showSettle.name}</strong> as paid?</p>
          <div className="bg-zinc-800 rounded-xl p-3 mb-4 space-y-1">
            <div className="flex justify-between items-center">
              <span className="text-zinc-400 text-sm">Total to settle</span>
              <span className="text-red-400 font-bold text-lg">£{showSettle.outstanding.toFixed(2)}</span>
            </div>
            {showSettle.finesOwed > 0 && <div className="flex justify-between text-xs text-zinc-500"><span>Fines</span><span className="text-amber-400">£{showSettle.finesOwed.toFixed(2)}</span></div>}
            {showSettle.subsOwed  > 0 && <div className="flex justify-between text-xs text-zinc-500"><span>Subs</span><span className="text-blue-400">£{showSettle.subsOwed.toFixed(2)}</span></div>}
          </div>
          <div className="flex gap-2">
            <Btn variant="success" className="flex-1" onClick={() => settleAll(showSettle.id)}>Settle All</Btn>
            <Btn variant="ghost" className="flex-1" onClick={() => setShowSettle(null)}>Cancel</Btn>
          </div>
        </Modal>
      )}
    </div>
  )
}
