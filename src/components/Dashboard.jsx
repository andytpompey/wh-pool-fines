import { useState } from 'react'
import { Badge, SegmentedControl } from '../App'

export default function Dashboard({ players, fineTypes, seasons, matches }) {
  const [seasonFilter, setSeasonFilter] = useState('all')
  const [view, setView] = useState('players')

  const filteredMatches = matches.filter(m => seasonFilter === 'all' || m.seasonId === seasonFilter)
  const allFines = filteredMatches.flatMap(m => m.fines.map(f => ({ ...f, matchDate: m.date, seasonId: m.seasonId })))
  const allSubs  = filteredMatches.flatMap(m => (m.subs ?? []).map(s => ({ ...s, matchDate: m.date, seasonId: m.seasonId })))

  const finesTotal = allFines.reduce((s, f) => s + f.cost, 0)
  const finesPaid  = allFines.filter(f => f.paid).reduce((s, f) => s + f.cost, 0)
  const subsTotal  = allSubs.reduce((s, sub) => s + sub.amount, 0)
  const subsPaid   = allSubs.filter(s => s.paid).reduce((s, sub) => s + sub.amount, 0)
  const totalAll   = finesTotal + subsTotal
  const totalPaid  = finesPaid + subsPaid
  const totalOwed  = totalAll - totalPaid

  const playerStats = players.map(p => {
    const pf       = allFines.filter(f => f.playerId === p.id)
    const ps       = allSubs.filter(s => s.playerId === p.id)
    const fTot     = pf.reduce((s, f) => s + f.cost, 0)
    const fPaid    = pf.filter(f => f.paid).reduce((s, f) => s + f.cost, 0)
    const sTot     = ps.reduce((s, sub) => s + sub.amount, 0)
    const sPaid    = ps.filter(s => s.paid).reduce((s, sub) => s + sub.amount, 0)
    const total    = fTot + sTot
    const paid     = fPaid + sPaid
    return { ...p, total, paid, owed: total - paid, count: pf.length, subCount: ps.length, finesOwed: fTot - fPaid, subsOwed: sTot - sPaid }
  }).filter(p => p.total > 0).sort((a, b) => b.owed - a.owed)

  const fineTypeStats = fineTypes.map(ft => {
    const pf    = allFines.filter(f => f.fineTypeId === ft.id)
    const total = pf.reduce((s, f) => s + f.cost, 0)
    const paid  = pf.filter(f => f.paid).reduce((s, f) => s + f.cost, 0)
    return { ...ft, total, paid, owed: total - paid, count: pf.length }
  }).filter(f => f.count > 0).sort((a, b) => b.count - a.count)

  const seasonStats = seasons.map(s => {
    const sm     = matches.filter(m => m.seasonId === s.id)
    const sf     = sm.flatMap(m => m.fines)
    const ss     = sm.flatMap(m => m.subs ?? [])
    const fTot   = sf.reduce((acc, f) => acc + f.cost, 0)
    const fPaid  = sf.filter(f => f.paid).reduce((acc, f) => acc + f.cost, 0)
    const sTot   = ss.reduce((acc, sub) => acc + sub.amount, 0)
    const sPaid  = ss.filter(sub => sub.paid).reduce((acc, sub) => acc + sub.amount, 0)
    const total  = fTot + sTot
    const paid   = fPaid + sPaid
    return { ...s, total, paid, owed: total - paid, count: sf.length, subCount: ss.length, matchCount: sm.length }
  }).filter(s => s.total > 0).sort((a, b) => b.total - a.total)

  const maxPlayerOwed = Math.max(...playerStats.map(p => p.owed), 1)
  const maxFineCount  = Math.max(...fineTypeStats.map(f => f.count), 1)

  return (
    <div>
      <div className="mb-4 rounded-xl border border-zinc-800 bg-zinc-900 px-3 py-3">
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-zinc-500">Dashboard</p>
            <h2 className="mt-1 text-lg font-bold text-white">Season overview</h2>
            <p className="mt-1 text-xs text-zinc-400">Track totals and balances for the selected team without leaving match-day views.</p>
          </div>
          <Badge color={seasonFilter === 'all' ? 'gray' : 'blue'}>{seasonFilter === 'all' ? 'All seasons' : seasons.find(season => season.id === seasonFilter)?.name ?? 'Season filter'}</Badge>
        </div>
      </div>

      <SegmentedControl
        className="mb-3"
        options={[{ value: 'all', label: 'All Seasons' }, ...seasons.map(season => ({ value: season.id, label: season.name }))]}
        value={seasonFilter}
        onChange={setSeasonFilter}
        scrollable
      />

      {/* Summary cards */}
      <div className="grid grid-cols-2 gap-2 mb-3">
        <div className="bg-zinc-800 border border-zinc-700 rounded-xl p-3">
          <div className="font-display font-bold text-2xl text-white">£{totalAll.toFixed(2)}</div>
          <div className="text-zinc-500 text-xs mt-0.5">{allFines.length} fines · {allSubs.length} subs</div>
          <div className="text-zinc-400 text-xs font-bold uppercase tracking-wider mt-1">Total</div>
        </div>
        <div className="bg-zinc-800 border border-zinc-700 rounded-xl p-3">
          <div className="font-display font-bold text-2xl text-red-400">£{totalOwed.toFixed(2)}</div>
          <div className="text-zinc-500 text-xs mt-0.5">{allFines.filter(f => !f.paid).length + allSubs.filter(s => !s.paid).length} unpaid</div>
          <div className="text-zinc-400 text-xs font-bold uppercase tracking-wider mt-1">Outstanding</div>
        </div>
        <div className="bg-zinc-800 border border-zinc-700 rounded-xl p-3">
          <div className="font-display font-bold text-2xl text-emerald-400">£{totalPaid.toFixed(2)}</div>
          <div className="text-zinc-500 text-xs mt-0.5">{allFines.filter(f => f.paid).length + allSubs.filter(s => s.paid).length} paid</div>
          <div className="text-zinc-400 text-xs font-bold uppercase tracking-wider mt-1">Collected</div>
        </div>
        <div className="bg-zinc-800 border border-zinc-700 rounded-xl p-3">
          <div className="font-display font-bold text-2xl text-amber-400">{totalAll > 0 ? Math.round((totalPaid / totalAll) * 100) : 0}%</div>
          <div className="text-zinc-500 text-xs mt-0.5">{filteredMatches.length} matches</div>
          <div className="text-zinc-400 text-xs font-bold uppercase tracking-wider mt-1">Collection Rate</div>
        </div>
      </div>

      {/* View toggle */}
      <SegmentedControl
        className="mb-3"
        options={[['players', 'By Player'], ['fineTypes', 'By Fine'], ['seasons', 'By Season']].map(([value, label]) => ({ value, label }))}
        value={view}
        onChange={setView}
        fullWidth
      />

      {/* Players view */}
      {view === 'players' && (
        <div className="space-y-3">
          {playerStats.length === 0 && <p className="text-zinc-500 text-sm text-center py-8">No fine data yet</p>}
          {playerStats.map((p, i) => (
            <div key={p.id} className="bg-zinc-800 border border-zinc-700 rounded-xl p-4">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <span className="w-6 h-6 rounded-full bg-zinc-700 flex items-center justify-center text-xs font-bold text-zinc-300">{i + 1}</span>
                  <span className="font-bold text-white">{p.name}</span>
                  <span className="text-zinc-500 text-xs">{p.count} fines · {p.subCount} subs</span>
                </div>
                <div className="text-right">
                  {p.owed > 0 ? <span className="font-bold text-red-400">£{p.owed.toFixed(2)} owed</span> : <span className="font-bold text-emerald-400">All clear</span>}
                </div>
              </div>
              <div className="h-2 bg-zinc-700 rounded-full overflow-hidden mb-2">
                <div className="h-full bg-emerald-500 rounded-full transition-all" style={{ width: p.total > 0 ? `${(p.paid / p.total) * 100}%` : '0%' }} />
              </div>
              <div className="flex justify-between text-xs text-zinc-400 mb-1">
                <span>Total <span className="text-white font-bold">£{p.total.toFixed(2)}</span></span>
                <span>Paid <span className="text-emerald-400 font-bold">£{p.paid.toFixed(2)}</span></span>
                <span>Owed <span className="text-red-400 font-bold">£{p.owed.toFixed(2)}</span></span>
              </div>
              {(p.finesOwed > 0 || p.subsOwed > 0) && (
                <div className="flex gap-3 text-xs text-zinc-500">
                  {p.finesOwed > 0 && <span>Fines <span className="text-amber-400">£{p.finesOwed.toFixed(2)}</span></span>}
                  {p.subsOwed  > 0 && <span>Subs <span className="text-blue-400">£{p.subsOwed.toFixed(2)}</span></span>}
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Fine types view */}
      {view === 'fineTypes' && (
        <div className="space-y-2">
          {fineTypeStats.length === 0 && <p className="text-zinc-500 text-sm text-center py-8">No fine data yet</p>}
          {fineTypeStats.map(f => (
            <div key={f.id} className="bg-zinc-800 border border-zinc-700 rounded-xl p-3">
              <div className="flex items-center justify-between mb-2">
                <div>
                  <span className="font-bold text-white text-sm">{f.name}</span>
                  <span className="text-amber-400 text-xs font-bold ml-2">£{f.cost.toFixed(2)} each</span>
                </div>
                <Badge color="gray">{f.count}x</Badge>
              </div>
              <div className="h-1.5 bg-zinc-700 rounded-full overflow-hidden mb-2">
                <div className="h-full bg-amber-500 rounded-full" style={{ width: `${(f.count / maxFineCount) * 100}%` }} />
              </div>
              <div className="flex justify-between text-xs text-zinc-400">
                <span>Total <span className="text-white font-bold">£{f.total.toFixed(2)}</span></span>
                <span>Paid <span className="text-emerald-400 font-bold">£{f.paid.toFixed(2)}</span></span>
                <span>Owed <span className="text-red-400 font-bold">£{f.owed.toFixed(2)}</span></span>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Seasons view */}
      {view === 'seasons' && (
        <div className="space-y-3">
          {seasonStats.length === 0 && <p className="text-zinc-500 text-sm text-center py-8">No fine data yet</p>}
          {seasonStats.map(s => (
            <div key={s.id} className="bg-zinc-800 border border-zinc-700 rounded-xl p-4">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <span className="font-bold text-white">{s.name}</span>
                  <Badge color={s.type === 'Cup' ? 'amber' : 'blue'}>{s.type}</Badge>
                </div>
                <span className="text-zinc-500 text-xs">{s.matchCount} matches · {s.count} fines · {s.subCount} subs</span>
              </div>
              <div className="h-2 bg-zinc-700 rounded-full overflow-hidden mb-2">
                <div className="h-full bg-emerald-500 rounded-full" style={{ width: s.total > 0 ? `${(s.paid / s.total) * 100}%` : '0%' }} />
              </div>
              <div className="flex justify-between text-xs text-zinc-400">
                <span>Total <span className="text-white font-bold">£{s.total.toFixed(2)}</span></span>
                <span>Paid <span className="text-emerald-400 font-bold">£{s.paid.toFixed(2)}</span></span>
                <span>Owed <span className="text-red-400 font-bold">£{s.owed.toFixed(2)}</span></span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
