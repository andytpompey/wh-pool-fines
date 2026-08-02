import { useCallback, useEffect, useState } from 'react'
import { Badge, Btn, Input, Sel } from '../App'
import * as commercial from '../lib/commercial'

const initialPrice = {
  offeringId: '', amountPounds: '10.00', currency: 'GBP', taxBehaviour: 'provider_calculated', market: 'GB',
  effectiveFrom: '', effectiveTo: '', subscriptionTreatment: 'retain', reason: '',
}
const initialDiscount = {
  name: '', type: 'percentage', value: '10', currency: 'GBP', validFrom: '', validUntil: '',
  totalLimit: '', perCustomerLimit: '1', reason: '',
}

function Card({ title, children }) {
  return <section className="rounded-2xl border border-zinc-800 bg-zinc-900 p-4"><h2 className="font-display text-lg font-bold text-white">{title}</h2><div className="mt-3">{children}</div></section>
}

export default function CommercialAdminPage({ isPlatformAdmin, onBack }) {
  const [dashboard, setDashboard] = useState(null)
  const [price, setPrice] = useState(initialPrice)
  const [discount, setDiscount] = useState(initialDiscount)
  const [enforcementReason, setEnforcementReason] = useState('Commercial launch readiness approved')
  const [catalogueAction, setCatalogueAction] = useState({ offeringId: '', code: '', reason: '' })
  const [draftChanges, setDraftChanges] = useState({ trialDays: '0', renewalBehaviour: 'manual', salesChannels: 'web,ios', firstPurchaseOnly: false, noPreviousTrial: false, paymentMethodRequired: false, conversionBehaviour: 'manual' })
  const [supportCases, setSupportCases] = useState([])
  const [issuedCode, setIssuedCode] = useState('')
  const [status, setStatus] = useState({ loading: true, saving: false, error: '', success: '' })

  const load = useCallback(async () => {
    if (!isPlatformAdmin) return
    setStatus(current => ({ ...current, loading: true, error: '' }))
    try {
      const [next, queue] = await Promise.all([commercial.getCommercialAdminDashboard(), commercial.getSupportAdminQueue()])
      setDashboard(next)
      setSupportCases(queue)
      setPrice(current => ({ ...current, offeringId: current.offeringId || next.offerings?.find(item => item.state === 'published')?.id || '' }))
      setCatalogueAction(current => ({ ...current, offeringId: current.offeringId || next.offerings?.find(item => item.state === 'published')?.id || '' }))
      setStatus(current => ({ ...current, loading: false }))
    } catch (error) {
      setStatus(current => ({ ...current, loading: false, error: error?.message ?? 'Commercial dashboard is unavailable.' }))
    }
  }, [isPlatformAdmin])

  useEffect(() => { load() }, [load])
  if (!isPlatformAdmin) return <Card title="Commercial administration"><p className="text-sm text-red-300">Platform administrator access is required.</p><Btn className="mt-3" variant="ghost" onClick={onBack}>Back</Btn></Card>
  if (status.loading) return <p className="text-sm text-zinc-400">Loading commercial controls…</p>

  const act = async (work, message) => {
    setStatus(current => ({ ...current, saving: true, error: '', success: '' }))
    try { await work(); await load(); setStatus(current => ({ ...current, saving: false, success: message })) }
    catch (error) { setStatus(current => ({ ...current, saving: false, error: error?.message ?? 'The commercial change failed.' })) }
  }
  const metrics = dashboard?.metrics?.[0]

  return <div className="space-y-4 pb-8">
    <div className="flex items-center justify-between gap-3"><div><p className="text-xs font-bold uppercase tracking-wider text-amber-400">Restricted</p><h1 className="font-display text-2xl font-bold">Commercial operations</h1></div><Btn variant="outline" size="sm" onClick={onBack}>Back to app</Btn></div>
    {status.error && <p role="alert" className="rounded-xl border border-red-900 bg-red-950/50 p-3 text-sm text-red-300">{status.error}</p>}
    {status.success && <p className="rounded-xl border border-emerald-900 bg-emerald-950/50 p-3 text-sm text-emerald-300">{status.success}</p>}

    <div className="grid grid-cols-2 gap-3">
      <Card title="Current month"><p className="text-2xl font-bold text-amber-400">{commercial.formatMoney(metrics?.gross_amount_minor ?? 0)}</p><p className="text-xs text-zinc-400">{metrics?.paid_team_seasons ?? 0} paid team-seasons</p></Card>
      <Card title="Readiness"><p className="text-2xl font-bold text-white">{dashboard?.enforcementGaps?.length ?? 0}</p><p className="text-xs text-zinc-400">uncovered active cycles</p></Card>
    </div>

    <Card title="Entitlement enforcement">
      <div className="flex flex-wrap items-center gap-2"><Badge color={dashboard?.enforcement === 'enforce' ? 'green' : 'amber'}>{dashboard?.enforcement ?? 'observe'}</Badge><span className="text-xs text-zinc-400">Enforce cannot be enabled while readiness gaps remain.</span></div>
      <Input label="Approval reason" value={enforcementReason} onChange={event => setEnforcementReason(event.target.value)} />
      <div className="flex gap-2"><Btn size="sm" variant="outline" disabled={status.saving} onClick={() => act(() => commercial.setCommercialEnforcement('observe', enforcementReason), 'Observe mode enabled.')}>Observe</Btn><Btn size="sm" disabled={status.saving || dashboard?.enforcementGaps?.length > 0} onClick={() => act(() => commercial.setCommercialEnforcement('enforce', enforcementReason), 'Enforcement enabled.')}>Enforce</Btn></div>
    </Card>

    <Card title="Schedule price">
      <Sel label="Offering" value={price.offeringId} onChange={event => setPrice({ ...price, offeringId: event.target.value })}>{dashboard?.offerings?.map(item => <option key={item.id} value={item.id}>{item.code} v{item.version} ({item.state})</option>)}</Sel>
      <div className="grid grid-cols-2 gap-2"><Input label="Price in pounds" type="number" min="0" step="0.01" value={price.amountPounds} onChange={event => setPrice({ ...price, amountPounds: event.target.value })}/><Input label="Effective from" type="datetime-local" value={price.effectiveFrom} onChange={event => setPrice({ ...price, effectiveFrom: event.target.value })}/></div>
      <Sel label="Existing purchases" value={price.subscriptionTreatment} onChange={event => setPrice({ ...price, subscriptionTreatment: event.target.value })}><option value="retain">Retain agreed price</option><option value="migrate_at_renewal">Change at renewal</option><option value="require_acceptance">Require acceptance</option></Sel>
      <Input label="Approval reason" value={price.reason} onChange={event => setPrice({ ...price, reason: event.target.value })}/>
      <Btn size="sm" disabled={status.saving || !price.offeringId || !price.effectiveFrom || price.reason.trim().length < 8} onClick={() => act(() => commercial.scheduleCommercialPrice(price), 'Price scheduled and audited.')}>Schedule price</Btn>
    </Card>

    <Card title="Offering lifecycle">
      <Sel label="Offering" value={catalogueAction.offeringId} onChange={event => setCatalogueAction({ ...catalogueAction, offeringId: event.target.value })}>{dashboard?.offerings?.map(item => <option key={item.id} value={item.id}>{item.code} v{item.version} ({item.state})</option>)}</Sel>
      <Input label="New code (clone only)" placeholder="team-season-next" value={catalogueAction.code} onChange={event => setCatalogueAction({ ...catalogueAction, code: event.target.value.toLowerCase() })}/>
      <Input label="Approval/change reason" value={catalogueAction.reason} onChange={event => setCatalogueAction({ ...catalogueAction, reason: event.target.value })}/>
      <div className="flex flex-wrap gap-2"><Btn size="sm" variant="outline" disabled={status.saving || !catalogueAction.code || catalogueAction.reason.trim().length < 8} onClick={() => act(() => commercial.cloneCommercialOffering(catalogueAction.offeringId, catalogueAction.code, catalogueAction.reason), 'Draft offering cloned.')}>Clone draft</Btn><Btn size="sm" disabled={status.saving || catalogueAction.reason.trim().length < 8 || dashboard?.offerings?.find(item => item.id === catalogueAction.offeringId)?.state !== 'draft'} onClick={() => act(() => commercial.publishCommercialOffering(catalogueAction.offeringId, catalogueAction.reason), 'Offering published.')}>Publish draft</Btn><Btn size="sm" variant="danger" disabled={status.saving || catalogueAction.reason.trim().length < 8 || dashboard?.offerings?.find(item => item.id === catalogueAction.offeringId)?.state !== 'published'} onClick={() => act(() => commercial.retireCommercialOffering(catalogueAction.offeringId, catalogueAction.reason), 'Offering retired for new sales.')}>Retire</Btn></div>
      {dashboard?.offerings?.find(item => item.id === catalogueAction.offeringId)?.state === 'draft' && <div className="mt-4 border-t border-zinc-800 pt-4"><h3 className="font-bold">Draft eligibility and trial</h3><div className="mt-2 grid grid-cols-2 gap-2"><Input label="Trial days" type="number" min="0" value={draftChanges.trialDays} onChange={event => setDraftChanges({ ...draftChanges, trialDays: event.target.value })}/><Sel label="Renewal" value={draftChanges.renewalBehaviour} onChange={event => setDraftChanges({ ...draftChanges, renewalBehaviour: event.target.value })}><option value="manual">Manual</option><option value="automatic">Automatic</option></Sel></div><Input label="Sales channels" value={draftChanges.salesChannels} onChange={event => setDraftChanges({ ...draftChanges, salesChannels: event.target.value })}/><div className="grid gap-2 text-sm text-zinc-300 sm:grid-cols-2">{[['firstPurchaseOnly','First purchase only'],['noPreviousTrial','Block repeat trials'],['paymentMethodRequired','Payment method required']].map(([key,label]) => <label key={key} className="flex items-center gap-2"><input type="checkbox" checked={draftChanges[key]} onChange={event => setDraftChanges({ ...draftChanges, [key]: event.target.checked })}/>{label}</label>)}</div><Btn className="mt-3" size="sm" variant="outline" disabled={status.saving || catalogueAction.reason.trim().length < 8} onClick={() => act(() => commercial.updateDraftCommercialOffering(catalogueAction.offeringId, { trialDays: Number(draftChanges.trialDays), renewalBehaviour: draftChanges.renewalBehaviour, salesChannels: draftChanges.salesChannels.split(',').map(value => value.trim()).filter(Boolean), eligibility: { firstPurchaseOnly: draftChanges.firstPurchaseOnly, noPreviousTrial: draftChanges.noPreviousTrial, paymentMethodRequired: draftChanges.paymentMethodRequired, conversionBehaviour: draftChanges.conversionBehaviour } }, catalogueAction.reason), 'Draft eligibility updated and audited.')}>Save draft rules</Btn></div>}
    </Card>

    <Card title="Publish discount">
      <Input label="Discount name" value={discount.name} onChange={event => setDiscount({ ...discount, name: event.target.value })}/>
      <div className="grid grid-cols-2 gap-2"><Sel label="Type" value={discount.type} onChange={event => setDiscount({ ...discount, type: event.target.value })}><option value="percentage">Percentage</option><option value="fixed">Fixed pounds</option></Sel><Input label={discount.type === 'percentage' ? 'Percent' : 'Pounds'} type="number" min="0" step={discount.type === 'percentage' ? '1' : '0.01'} value={discount.value} onChange={event => setDiscount({ ...discount, value: event.target.value })}/></div>
      <div className="grid grid-cols-2 gap-2"><Input label="Valid from" type="datetime-local" value={discount.validFrom} onChange={event => setDiscount({ ...discount, validFrom: event.target.value })}/><Input label="Valid until" type="datetime-local" value={discount.validUntil} onChange={event => setDiscount({ ...discount, validUntil: event.target.value })}/></div>
      <Input label="Approval reason" value={discount.reason} onChange={event => setDiscount({ ...discount, reason: event.target.value })}/>
      <Btn size="sm" disabled={status.saving || !discount.validFrom || discount.name.trim().length < 3 || discount.reason.trim().length < 8} onClick={() => act(() => commercial.createCommercialDiscount({ ...discount, value: discount.type === 'fixed' ? Number(discount.value) * 100 : discount.value }), 'Discount published and audited.')}>Publish discount</Btn>
      {dashboard?.discounts?.filter(item => item.state === 'published').map(item => <div key={item.id} className="mt-3 flex flex-wrap items-center justify-between gap-2 rounded-lg bg-zinc-800 p-3"><span className="text-sm font-bold">{item.name}</span><Btn size="sm" variant="outline" disabled={status.saving} onClick={() => act(async () => { const result = await commercial.issueCommercialDiscountCode(item.id, `Issue single use code for ${item.name}`); setIssuedCode(result.code) }, 'Single-use Stripe promotion code issued. Copy it now.')}>Issue code</Btn></div>)}
      {issuedCode && <div className="mt-3 rounded-lg border border-amber-700 bg-amber-950/30 p-3"><p className="text-xs text-zinc-400">Shown once — copy this code now</p><p className="mt-1 font-mono text-lg font-bold text-amber-300">{issuedCode}</p></div>}
    </Card>

    <Card title="Reconciliation and support">
      <div className="grid grid-cols-2 gap-3 text-sm"><div><p className="text-2xl font-bold">{dashboard?.reconciliationIssues?.length ?? 0}</p><p className="text-zinc-400">payment issues</p></div><div><p className="text-2xl font-bold">{dashboard?.support?.openCases ?? 0}</p><p className="text-zinc-400">open support cases</p></div></div>
      {(dashboard?.reconciliationIssues?.length > 0 || dashboard?.enforcementGaps?.length > 0) && <div className="mt-3 space-y-2">{dashboard.reconciliationIssues?.slice(0, 10).map(item => <p key={`${item.issue_type}-${item.entity_id}`} className="rounded-lg bg-zinc-800 p-2 text-xs text-zinc-300">{item.issue_type}: {item.entity_id}</p>)}{dashboard.enforcementGaps?.slice(0, 10).map(item => <p key={item.playing_cycle_id} className="rounded-lg bg-zinc-800 p-2 text-xs text-zinc-300">Access gap: {item.name}</p>)}</div>}
    </Card>
    <Card title="Support queue">
      {supportCases.length === 0 ? <p className="text-sm text-zinc-400">No open cases.</p> : <div className="space-y-3">{supportCases.slice(0, 20).map(item => <SupportCase key={item.id} item={item} saving={status.saving} onUpdate={input => act(() => commercial.updateSupportCase(input), `Support case ${item.reference} updated.`)}/>)}</div>}
    </Card>
  </div>
}

function SupportCase({ item, saving, onUpdate }) {
  const [form, setForm] = useState({ status: item.status, priority: item.priority, customerMessage: '', internalNote: '', reason: 'Support case triage update' })
  return <div className="rounded-xl border border-zinc-800 bg-zinc-950 p-3"><div className="flex items-start justify-between gap-2"><div><p className="font-bold text-white">{item.reference}: {item.subject}</p><p className="text-xs text-zinc-400">{item.case_type} · {item.contact_email}</p></div><Badge color={item.priority === 'urgent' ? 'red' : item.priority === 'high' ? 'amber' : 'gray'}>{item.priority}</Badge></div><p className="mt-2 text-sm text-zinc-300">{item.description}</p><div className="mt-3 grid grid-cols-2 gap-2"><Sel label="State" value={form.status} onChange={event => setForm({ ...form, status: event.target.value })}><option value="open">Open</option><option value="acknowledged">Acknowledged</option><option value="waiting_customer">Waiting customer</option><option value="resolved">Resolved</option><option value="closed">Closed</option></Sel><Sel label="Priority" value={form.priority} onChange={event => setForm({ ...form, priority: event.target.value })}><option value="low">Low</option><option value="normal">Normal</option><option value="high">High</option><option value="urgent">Urgent</option></Sel></div><Input label="Customer-visible update (optional)" value={form.customerMessage} onChange={event => setForm({ ...form, customerMessage: event.target.value })}/><Input label="Internal note (optional)" value={form.internalNote} onChange={event => setForm({ ...form, internalNote: event.target.value })}/><Btn size="sm" disabled={saving || form.reason.trim().length < 8} onClick={() => onUpdate({ caseId: item.id, ...form })}>Update case</Btn></div>
}
