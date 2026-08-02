import { createClient } from 'npm:@supabase/supabase-js@2'

const origin = Deno.env.get('PUBLIC_APP_ORIGIN') ?? ''
const headers = {
  'Access-Control-Allow-Origin': origin,
  'Access-Control-Allow-Headers': 'content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok',{headers})
  if (request.method !== 'POST') return json({message:'Method not allowed'},405)
  if ((request.headers.get('content-length') ? Number(request.headers.get('content-length')) : 0) > 20_000) return json({message:'Request is too large'},413)
  let body: Record<string,unknown>
  try { body = await request.json() } catch { return json({message:'Invalid form'},400) }
  if (String(body.website ?? '').trim()) return json({received:true,reference:'SUPPORT-RECEIVED'},200)
  const caseType = body.caseType === 'league_enquiry' ? 'league_enquiry' : 'support'
  const name = clean(body.name,100)
  const email = clean(body.email,254).toLowerCase()
  const organisation = clean(body.organisation,160)
  const subject = clean(body.subject,160)
  const description = clean(body.description,4000)
  const teamCount = body.approximateTeamCount ? Number(body.approximateTeamCount) : null
  if (!email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/) || !subject || description.length < 10) return json({message:'Complete the required contact, subject and description fields'},400)
  if (teamCount !== null && (!Number.isInteger(teamCount) || teamCount < 1 || teamCount > 10000)) return json({message:'Approximate team count is invalid'},400)
  const supabaseURL=Deno.env.get('SUPABASE_URL'),serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseURL||!serviceKey) return json({message:'Support intake is unavailable'},503)
  const admin=createClient(supabaseURL,serviceKey,{auth:{persistSession:false}})
  const forwarded=request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown'
  const fingerprint=`${forwarded}|${request.headers.get('user-agent') ?? ''}`
  const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(fingerprint))
  const requestHash=[...new Uint8Array(digest)].map(value=>value.toString(16).padStart(2,'0')).join('')
  const windowStart=new Date();windowStart.setUTCMinutes(0,0,0)
  const {data:limit}=await admin.from('public_request_limits').select('request_count').eq('request_hash',requestHash).eq('request_kind','support').eq('window_started_at',windowStart.toISOString()).maybeSingle()
  if ((limit?.request_count ?? 0)>=5) return json({message:'Too many requests. Try again later.'},429)
  await admin.from('public_request_limits').upsert({request_hash:requestHash,request_kind:'support',window_started_at:windowStart.toISOString(),request_count:(limit?.request_count ?? 0)+1},{onConflict:'request_hash,request_kind,window_started_at'})
  const reference=`RB-${crypto.randomUUID().split('-')[0].toUpperCase()}`
  const result=await admin.from('support_cases').insert({
    reference,case_type:caseType,contact_name:name||null,contact_email:email,
    team_or_league_name:organisation||null,approximate_team_count:teamCount,subject,description,
    consent_to_contact:body.consentToContact!==false,response_due_at:new Date(Date.now()+2*86400000).toISOString(),
  })
  if(result.error)return json({message:'Your request could not be recorded. Email support instead.'},503)
  return json({received:true,reference,responseTarget:'We aim to respond within two working days.'},201)
})

function clean(value:unknown,max:number){return String(value??'').trim().replace(/[\u0000-\u001F\u007F]/g,' ').slice(0,max)}
function json(body:unknown,status:number){return new Response(JSON.stringify(body),{status,headers:{...headers,'Content-Type':'application/json','Cache-Control':'no-store'}})}
