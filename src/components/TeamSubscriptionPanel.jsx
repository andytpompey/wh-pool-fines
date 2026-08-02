import { useEffect, useState } from 'react'
import { Badge, Btn } from '../App'
import * as commercial from '../lib/commercial'

const ACTIVE_STATES = new Set(['active', 'trial', 'grace', 'complimentary'])

export default function TeamSubscriptionPanel({ team, seasons, canManageTeam }) {
  const [offer, setOffer] = useState(null)
  const [cycles, setCycles] = useState([])
  const [entitlements, setEntitlements] = useState([])
  const [editing, setEditing] = useState(null)
  const [billing, setBilling] = useState(null)
  const [pendingTransfers, setPendingTransfers] = useState([])
  const [transfer, setTransfer] = useState({ email: '', reason: '' })
  const [status, setStatus] = useState({ loading: true, buying: '', error: '' })

  useEffect(() => {
    let live = true
    setStatus({ loading: true, buying: '', error: '' })
    Promise.all([commercial.getPublishedTeamSeasonOffer(), commercial.getTeamPlayingCycles(team.id), commercial.getTeamBillingContext(team.id), commercial.getPendingBillingTransfers()]).then(async ([nextOffer, nextCycles, nextBilling, nextTransfers]) => {
      const nextEntitlements = await commercial.getTeamEntitlements(team.id, nextCycles)
      if (!live) return
      setOffer(nextOffer)
      setCycles(nextCycles)
      setEntitlements(nextEntitlements)
      setBilling(nextBilling)
      setPendingTransfers(nextTransfers)
      setStatus({ loading: false, buying: '', error: '' })
    }).catch(error => {
      if (live) setStatus({ loading: false, buying: '', error: error?.message ?? 'Subscription status is unavailable.' })
    })
    return () => { live = false }
  }, [team.id, seasons])

  const buy = async (playingCycleId) => {
    setStatus(current => ({ ...current, buying: playingCycleId, error: '' }))
    try {
      const checkoutUrl = await commercial.createTeamSeasonCheckout({ teamId: team.id, playingCycleId })
      window.location.assign(checkoutUrl)
    } catch (error) {
      setStatus(current => ({ ...current, buying: '', error: error?.message ?? 'Checkout could not be started.' }))
    }
  }

  return (
    <section className="space-y-4">
      <div className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-xs font-bold uppercase tracking-wider text-zinc-400">Team subscription</p>
            <h3 className="mt-1 text-xl font-bold text-white">{offer?.commercial_products?.name ?? 'RooBin Fines Team'}</h3>
            <p className="mt-2 text-sm text-zinc-400">One payment covers this team&apos;s League, Cup and Plate records for the selected playing cycle.</p>
          </div>
          <Badge color="amber">{offer ? `${commercial.formatMoney(offer.price.amount_minor, offer.price.currency)} / season` : 'Offer unavailable'}</Badge>
        </div>
        <p className="mt-3 text-xs text-zinc-500">Web checkout is securely hosted by Stripe. Apple Pay appears automatically on supported devices. iPhone in-app purchases use Apple&apos;s App Store checkout.</p>
        {canManageTeam && <Btn variant="outline" size="sm" className="mt-3" onClick={async () => {
          try { await commercial.openBillingPortal(team.id) }
          catch (error) { setStatus(current => ({ ...current, error: error?.message ?? 'Billing portal is unavailable.' })) }
        }}>Manage web billing</Btn>}
      </div>

      {status.error && <p role="alert" className="rounded-xl border border-red-900 bg-red-950/50 p-3 text-sm text-red-300">{status.error}</p>}
      {status.loading ? <p className="text-sm text-zinc-400">Loading subscription status…</p> : cycles.length === 0 ? (
        <p className="rounded-xl border border-zinc-800 bg-zinc-900 p-4 text-sm text-zinc-400">Create or import a season before purchasing access.</p>
      ) : (
        <div className="space-y-2">
          {entitlements.map(item => {
            const active = ACTIVE_STATES.has(item.state)
            const hasBoundary = Boolean(item.cycle.startsOn && item.cycle.endsOn)
            return (
              <div key={item.cycle.id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-zinc-800 bg-zinc-900 p-4">
                <div>
                  <p className="font-bold text-white">{item.cycle.name}</p>
                  <p className="mt-1 text-xs text-zinc-400">{active && item.validUntil ? `Access until ${new Date(item.validUntil).toLocaleDateString('en-GB')}` : hasBoundary ? `${item.cycle.startsOn} to ${item.cycle.endsOn}` : 'Set cycle dates before purchase'}</p>
                  {canManageTeam && item.purchaser && <p className="mt-1 text-xs text-zinc-500">Purchaser: {item.purchaser}</p>}
                </div>
                {active ? <Badge color={item.state === 'grace' ? 'amber' : 'green'}>{item.state}</Badge> : (
                  <div className="flex gap-2">
                    {canManageTeam && <Btn variant="outline" size="sm" onClick={() => setEditing({ ...item.cycle })}>Dates</Btn>}
                    <Btn size="sm" disabled={!canManageTeam || !offer || !hasBoundary || status.buying === item.cycle.id} onClick={() => buy(item.cycle.id)}>
                      {status.buying === item.cycle.id ? 'Opening…' : `Buy ${offer ? commercial.formatMoney(offer.price.amount_minor, offer.price.currency) : ''}`}
                    </Btn>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
      {!canManageTeam && <p className="text-xs text-zinc-500">Only a captain or vice-captain can purchase team access.</p>}
      {pendingTransfers.filter(item => item.teamId === team.id).map(item => <div key={item.id} className="rounded-xl border border-amber-700 bg-amber-950/30 p-4"><p className="font-bold text-white">Billing handover requested</p><p className="mt-1 text-xs text-zinc-400">Accepting makes you the billing owner for {item.teamName} without changing team roles or invoice history. Expires {new Date(item.expiresAt).toLocaleDateString('en-GB')}.</p><Btn size="sm" className="mt-3" onClick={async () => { try { await commercial.acceptBillingTransfer(item.id); setPendingTransfers(current => current.filter(value => value.id !== item.id)); setBilling(await commercial.getTeamBillingContext(team.id)) } catch (error) { setStatus(current => ({ ...current, error: error?.message ?? 'Billing handover could not be accepted.' })) } }}>Accept billing handover</Btn></div>)}
      {billing?.isOwner && <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4"><h4 className="font-bold text-white">Transfer billing administration</h4><p className="mt-1 text-xs text-zinc-400">The replacement must already have a verified RooBin account. This does not change captaincy, payment history or the provider customer.</p><label className="mt-3 block text-xs text-zinc-400">Replacement email<input className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-950 p-2 text-white" type="email" value={transfer.email} onChange={event => setTransfer(current => ({ ...current, email: event.target.value }))}/></label><label className="mt-2 block text-xs text-zinc-400">Reason<input className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-950 p-2 text-white" value={transfer.reason} onChange={event => setTransfer(current => ({ ...current, reason: event.target.value }))}/></label><Btn size="sm" variant="outline" className="mt-3" disabled={!transfer.email || transfer.reason.trim().length < 8} onClick={async () => { try { await commercial.initiateBillingTransfer(billing.id, transfer.email, transfer.reason); setTransfer({ email: '', reason: '' }); setStatus(current => ({ ...current, error: '' })) } catch (error) { setStatus(current => ({ ...current, error: error?.message ?? 'Billing handover could not be started.' })) } }}>Request handover</Btn></div>}
      {editing && (
        <div className="rounded-xl border border-amber-800 bg-amber-950/20 p-4">
          <h4 className="font-bold text-white">Set paid cycle boundary</h4>
          <p className="mt-1 text-xs text-zinc-400">League, Cup and Plate records linked to this cycle share one purchase.</p>
          <div className="mt-3 grid grid-cols-2 gap-2">
            <label className="text-xs text-zinc-400">Starts<input className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-900 p-2 text-white" type="date" value={editing.startsOn ?? ''} onChange={event => setEditing(current => ({ ...current, startsOn: event.target.value }))} /></label>
            <label className="text-xs text-zinc-400">Ends<input className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-900 p-2 text-white" type="date" value={editing.endsOn ?? ''} onChange={event => setEditing(current => ({ ...current, endsOn: event.target.value }))} /></label>
          </div>
          <div className="mt-3 flex gap-2">
            <Btn size="sm" disabled={!editing.startsOn || !editing.endsOn} onClick={async () => {
              try {
                await commercial.updatePlayingCycle(editing)
                const nextCycles = await commercial.getTeamPlayingCycles(team.id)
                setCycles(nextCycles)
                setEntitlements(await commercial.getTeamEntitlements(team.id, nextCycles))
                setEditing(null)
              } catch (error) { setStatus(current => ({ ...current, error: error?.message ?? 'Cycle dates could not be saved.' })) }
            }}>Save dates</Btn>
            <Btn variant="ghost" size="sm" onClick={() => setEditing(null)}>Cancel</Btn>
          </div>
        </div>
      )}
    </section>
  )
}
