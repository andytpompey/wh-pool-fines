import { useEffect, useState } from 'react'
import { Badge, Btn } from '../App'
import * as commercial from '../lib/commercial'

const ACTIVE_STATES = new Set(['active', 'trial', 'grace'])

export default function TeamSubscriptionPanel({ team, seasons, canManageTeam }) {
  const [offer, setOffer] = useState(null)
  const [entitlements, setEntitlements] = useState([])
  const [status, setStatus] = useState({ loading: true, buying: '', error: '' })

  useEffect(() => {
    let live = true
    setStatus({ loading: true, buying: '', error: '' })
    Promise.all([
      commercial.getPublishedTeamSeasonOffer(),
      commercial.getTeamEntitlements(team.id, seasons),
    ]).then(([nextOffer, nextEntitlements]) => {
      if (!live) return
      setOffer(nextOffer)
      setEntitlements(nextEntitlements)
      setStatus({ loading: false, buying: '', error: '' })
    }).catch(error => {
      if (live) setStatus({ loading: false, buying: '', error: error?.message ?? 'Subscription status is unavailable.' })
    })
    return () => { live = false }
  }, [team.id, seasons])

  const buy = async (seasonId) => {
    setStatus(current => ({ ...current, buying: seasonId, error: '' }))
    try {
      const checkoutUrl = await commercial.createTeamSeasonCheckout({ teamId: team.id, seasonId })
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
      </div>

      {status.error && <p role="alert" className="rounded-xl border border-red-900 bg-red-950/50 p-3 text-sm text-red-300">{status.error}</p>}
      {status.loading ? <p className="text-sm text-zinc-400">Loading subscription status…</p> : seasons.length === 0 ? (
        <p className="rounded-xl border border-zinc-800 bg-zinc-900 p-4 text-sm text-zinc-400">Create or import a season before purchasing access.</p>
      ) : (
        <div className="space-y-2">
          {entitlements.map(item => {
            const active = ACTIVE_STATES.has(item.state)
            return (
              <div key={item.season.id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-zinc-800 bg-zinc-900 p-4">
                <div>
                  <p className="font-bold text-white">{item.season.name}</p>
                  <p className="mt-1 text-xs text-zinc-400">{active && item.validUntil ? `Access until ${new Date(item.validUntil).toLocaleDateString('en-GB')}` : 'No paid access recorded'}</p>
                </div>
                {active ? <Badge color={item.state === 'grace' ? 'amber' : 'green'}>{item.state}</Badge> : (
                  <Btn size="sm" disabled={!canManageTeam || !offer || status.buying === item.season.id} onClick={() => buy(item.season.id)}>
                    {status.buying === item.season.id ? 'Opening…' : `Buy ${offer ? commercial.formatMoney(offer.price.amount_minor, offer.price.currency) : ''}`}
                  </Btn>
                )}
              </div>
            )
          })}
        </div>
      )}
      {!canManageTeam && <p className="text-xs text-zinc-500">Only a captain or vice-captain can purchase team access.</p>}
    </section>
  )
}
