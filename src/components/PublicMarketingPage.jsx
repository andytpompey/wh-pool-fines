import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { formatMoney, getPublishedTeamSeasonOffer } from '../lib/commercial'

const NAV = [['Home','/'],['How it works','/how-it-works'],['Leagues','/leagues'],['Pricing','/pricing'],['Help','/help'],['Status','/status']]

export default function PublicMarketingPage({ page }) {
  useEffect(() => {
    const pageTitle = `${title(page)} | RooBin`
    const description = descriptions[page] ?? descriptions.home
    const canonical = new URL(location.pathname, import.meta.env.VITE_PUBLIC_SITE_ORIGIN || location.origin).toString()
    document.title = pageTitle
    setMeta('meta[name="description"]', 'name', 'description', description)
    setMeta('meta[property="og:title"]', 'property', 'og:title', pageTitle)
    setMeta('meta[property="og:description"]', 'property', 'og:description', description)
    setMeta('meta[property="og:url"]', 'property', 'og:url', canonical)
    let link = document.querySelector('link[rel="canonical"]')
    if (!link) { link = document.createElement('link'); link.rel = 'canonical'; document.head.appendChild(link) }
    link.href = canonical
  }, [page])
  return (
    <main className="min-h-screen bg-zinc-950 text-zinc-100">
      <header className="border-b border-zinc-800 bg-black/80 px-4 py-4">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4">
          <a href="/" aria-label="RooBin home"><img src="/images/roo-bin-banner-transparent.png" alt="RooBin" className="h-14 w-44 object-contain" /></a>
          <nav aria-label="Main" className="flex flex-wrap items-center gap-4 text-sm">
            {NAV.map(([label,path])=><a key={path} href={path} className="text-zinc-300 hover:text-amber-400">{label}</a>)}
            <a href="/app" className="rounded-lg bg-amber-500 px-4 py-2 font-bold text-zinc-950 hover:bg-amber-400">Open RooBin</a>
          </nav>
        </div>
      </header>
      {page==='home'&&<Home/>}
      {page==='how'&&<HowItWorks/>}
      {page==='leagues'&&<Leagues/>}
      {page==='pricing'&&<Pricing/>}
      {page==='help'&&<Help/>}
      {page==='contact'&&<Contact/>}
      {page==='status'&&<Status/>}
      <Footer/>
    </main>
  )
}

function Home(){return <><Hero eyebrow="Team fines without the faff" title="Keep the banter. Lose the spreadsheet." body="RooBin gives pub-sports teams one shared place for fixtures, fines, subs and payment status."/><Cards items={[
  ['For captains','Set up the team, import fixtures, record a match and see who still owes what.'],
  ['For players','See your own entries and the team leaderboard without chasing a spreadsheet.'],
  ['For leagues','Run a structured pilot across teams with consistent access and support.'],
]}/><CTA/></>}
function HowItWorks(){return <><Hero eyebrow="How it works" title="From fixture to settled ledger" body="RooBin follows the way a real team runs a match."/><Steps items={[
  ['1','Create or join the team','A captain creates the team and invites players.'],
  ['2','Create or import the season','Use manual fixtures or captain-triggered RackEm import.'],
  ['3','Record the match','Select players, drivers, fines and any team subs.'],
  ['4','Track settlement','Mark entries paid while preserving the team history.'],
]}/></>}
function Leagues(){return <><Hero eyebrow="League pilots" title="Give every team the same clean starting point" body="RooBin can support a controlled league pilot without making every player buy an individual subscription."/><Cards items={[
  ['Team-based access','One authorised payer covers every member of the team for a playing cycle.'],
  ['League coverage','A league arrangement can cover registered teams without duplicate captain purchases.'],
  ['Measured pilot','Activation, match use and support demand can be reviewed without exposing private fine descriptions.'],
]}/><div className="mx-auto max-w-5xl px-4 pb-16"><a href="/contact?type=league" className="rounded-lg bg-amber-500 px-5 py-3 font-bold text-zinc-950">Enquire about a pilot</a></div></>}
function Pricing(){const[offer,setOffer]=useState(null);useEffect(()=>{getPublishedTeamSeasonOffer().then(setOffer).catch(()=>setOffer(null))},[]);return <><Hero eyebrow="Simple Team pricing" title={offer?`${formatMoney(offer.price.amount_minor,offer.price.currency)} per team per season`:'Team-season pricing'} body="One payment covers authorised members and the League, Cup and Plate records linked to the same normal playing cycle."/><div className="mx-auto max-w-3xl px-4 pb-16"><div className="rounded-3xl border border-amber-700/60 bg-zinc-900 p-7"><h2 className="text-2xl font-bold">RooBin Fines Team</h2><ul className="mt-5 space-y-3 text-zinc-300"><li>✓ No per-player charge</li><li>✓ Team, roster and history carry into renewal</li><li>✓ Web checkout supports cards and eligible wallets</li><li>✓ iPhone purchases use secure App Store checkout</li></ul><p className="mt-6 text-sm text-zinc-500">The initial offer is a deliberate purchase for a named playing cycle. It does not silently renew against a calendar period.</p><a href="/app" className="mt-6 inline-block rounded-lg bg-amber-500 px-5 py-3 font-bold text-zinc-950">Start or open a team</a></div></div></>}
function Help(){return <><Hero eyebrow="Help" title="Quick answers for teams" body="Never send support a sign-in code, team unlock code or full payment details."/><div className="mx-auto max-w-3xl space-y-4 px-4 pb-16">{[
  ['How do I join?','Ask your captain for the team join code or use the invitation sent to your verified email address.'],
  ['Who buys access?','A captain or vice-captain buys access for the team. Ordinary players are not prompted to pay.'],
  ['What counts as a season?','One normal team playing cycle. League, Cup and Plate records linked to that cycle share access.'],
  ['What happens on expiry?','Team data is retained. Paid operational writes become restricted after the configured grace period; renewal restores access.'],
  ['Can I restore an iPhone purchase?','Yes. Open Settings, Team subscription, then Restore App Store purchases.'],
].map(([q,a])=><details key={q} className="rounded-xl border border-zinc-800 bg-zinc-900 p-4"><summary className="cursor-pointer font-bold text-white">{q}</summary><p className="mt-3 text-zinc-400">{a}</p></details>)}<a href="/contact" className="inline-block text-amber-400">Contact support →</a></div></>}

function Contact(){const params=new URLSearchParams(location.search);const[form,setForm]=useState({caseType:params.get('type')==='league'?'league_enquiry':'support',name:'',email:'',organisation:'',approximateTeamCount:'',subject:'',description:'',website:'',consentToContact:true});const[state,setState]=useState({sending:false,error:'',success:''});const submit=async e=>{e.preventDefault();setState({sending:true,error:'',success:''});const{data,error}=await supabase.functions.invoke('public-support',{body:form});if(error)setState({sending:false,error:error.message||'Request could not be sent.',success:''});else setState({sending:false,error:'',success:`Request received. Reference ${data.reference}. ${data.responseTarget}`})};return <><Hero eyebrow="Contact" title={form.caseType==='league_enquiry'?'League pilot enquiry':'Contact RooBin support'} body="Tell us only what we need to route and investigate your request."/><form onSubmit={submit} className="mx-auto grid max-w-2xl gap-4 px-4 pb-16"><input className="hidden" tabIndex="-1" autoComplete="off" value={form.website} onChange={e=>setForm({...form,website:e.target.value})}/>{[['Name','name','text'],['Email','email','email'],['Team or league','organisation','text'],['Subject','subject','text']].map(([label,key,type])=><label key={key} className="text-sm text-zinc-300">{label}{['email','subject'].includes(key)&&' *'}<input required={['email','subject'].includes(key)} type={type} value={form[key]} onChange={e=>setForm({...form,[key]:e.target.value})} className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-900 p-3 text-white"/></label>)}{form.caseType==='league_enquiry'&&<label className="text-sm text-zinc-300">Approximate teams<input type="number" min="1" max="10000" value={form.approximateTeamCount} onChange={e=>setForm({...form,approximateTeamCount:e.target.value})} className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-900 p-3 text-white"/></label>}<label className="text-sm text-zinc-300">Description *<textarea required minLength="10" rows="6" value={form.description} onChange={e=>setForm({...form,description:e.target.value})} className="mt-1 w-full rounded-lg border border-zinc-700 bg-zinc-900 p-3 text-white"/></label>{state.error&&<p className="text-red-400">{state.error}</p>}{state.success&&<p className="text-emerald-400">{state.success}</p>}<button disabled={state.sending} className="rounded-lg bg-amber-500 px-5 py-3 font-bold text-zinc-950 disabled:opacity-50">{state.sending?'Sending…':'Send request'}</button></form></>}
function Status(){const[components,setComponents]=useState([]);const[incidents,setIncidents]=useState([]);const[updates,setUpdates]=useState([]);useEffect(()=>{Promise.all([supabase.from('service_components').select('*').order('name'),supabase.from('service_incidents').select('*').order('started_at',{ascending:false}).limit(20),supabase.from('service_incident_updates').select('*').order('published_at',{ascending:false}).limit(100)]).then(([a,b,c])=>{setComponents(a.data??[]);setIncidents(b.data??[]);setUpdates(c.data??[])})},[]);return <><Hero eyebrow="Service status" title="RooBin availability" body="Current component state and recent public incidents."/><div className="mx-auto max-w-3xl space-y-3 px-4 pb-16">{components.map(c=><div key={c.code} className="flex justify-between rounded-xl border border-zinc-800 bg-zinc-900 p-4"><span>{c.name}</span><span className={c.status==='operational'?'text-emerald-400':'text-amber-400'}>{c.status.replaceAll('_',' ')}</span></div>)}<h2 className="pt-6 text-xl font-bold">Recent incidents</h2>{incidents.length?incidents.map(i=><article key={i.id} className="rounded-xl border border-zinc-800 bg-zinc-900 p-4"><div className="flex justify-between"><strong>{i.title}</strong><span>{i.status}</span></div><p className="mt-2 text-zinc-400">{i.public_message}</p><div className="mt-3 space-y-2 border-t border-zinc-800 pt-3">{updates.filter(update=>update.incident_id===i.id).map(update=><div key={update.id} className="text-sm"><p className="text-xs text-zinc-500">{new Date(update.published_at).toLocaleString('en-GB')} · {update.status}</p><p className="text-zinc-300">{update.public_message}</p>{update.mitigation&&<p className="text-zinc-400">Mitigation: {update.mitigation}</p>}</div>)}</div></article>):<p className="text-zinc-400">No public incidents recorded.</p>}</div></>}
function Hero({eyebrow,title,body}){return <section className="mx-auto max-w-5xl px-4 py-16"><p className="font-bold uppercase tracking-widest text-amber-400">{eyebrow}</p><h1 className="mt-3 max-w-4xl text-4xl font-black leading-tight sm:text-6xl">{title}</h1><p className="mt-5 max-w-2xl text-lg leading-8 text-zinc-400">{body}</p></section>}
function Cards({items}){return <section className="mx-auto grid max-w-5xl gap-4 px-4 pb-16 md:grid-cols-3">{items.map(([h,b])=><article key={h} className="rounded-2xl border border-zinc-800 bg-zinc-900 p-6"><h2 className="text-xl font-bold text-white">{h}</h2><p className="mt-3 leading-7 text-zinc-400">{b}</p></article>)}</section>}
function Steps({items}){return <section className="mx-auto max-w-4xl space-y-4 px-4 pb-16">{items.map(([n,h,b])=><article key={n} className="flex gap-5 rounded-2xl border border-zinc-800 bg-zinc-900 p-6"><span className="text-3xl font-black text-amber-400">{n}</span><div><h2 className="text-xl font-bold">{h}</h2><p className="mt-2 text-zinc-400">{b}</p></div></article>)}</section>}
function CTA(){return <section className="mx-auto max-w-5xl px-4 pb-16"><div className="rounded-3xl bg-amber-500 p-8 text-zinc-950"><h2 className="text-3xl font-black">Ready to bin the spreadsheet?</h2><div className="mt-5 flex gap-3"><a href="/app" className="rounded-lg bg-zinc-950 px-5 py-3 font-bold text-white">Open RooBin</a><a href="/pricing" className="rounded-lg border border-zinc-900 px-5 py-3 font-bold">See pricing</a></div></div></section>}
function Footer(){return <footer className="border-t border-zinc-800 px-4 py-8 text-sm text-zinc-500"><div className="mx-auto flex max-w-5xl flex-wrap gap-5"><span>© 2026 RooBin / TroveFinds</span><a href="/privacy">Privacy</a><a href="/terms">Terms</a><a href="/support">Support & deletion</a><a href="/contact">Contact</a></div></footer>}
function title(page){return({home:'Team fines tracker',how:'How it works',leagues:'Leagues',pricing:'Pricing',help:'Help',contact:'Contact',status:'Service status'})[page]??'RooBin'}
const descriptions={home:'Keep pub-sports team fixtures, fines, subs and payment status in one shared place.',how:'See how RooBin takes a team from fixture to settled fines and subs ledger.',leagues:'Run a controlled RooBin league pilot with consistent team access and support.',pricing:'RooBin Fines Team costs £10 per team per normal playing cycle.',help:'Help for joining teams, seasons, paid access, renewal, expiry and App Store restore.',contact:'Contact RooBin support or enquire about a league pilot.',status:'Current RooBin component status and recent service incidents.'}
function setMeta(selector,attribute,key,content){let element=document.querySelector(selector);if(!element){element=document.createElement('meta');element.setAttribute(attribute,key);document.head.appendChild(element)}element.setAttribute('content',content)}
