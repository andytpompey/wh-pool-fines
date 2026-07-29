import { getRackemLeagues, getRackemTeamPage, getRackemTeams } from '../server/rackem.js'

const CACHE_HEADERS = {
  leagues: 'public, s-maxage=43200, stale-while-revalidate=86400',
  teams: 'public, s-maxage=1800, stale-while-revalidate=3600',
  team: 'private, no-store',
}

export default async function handler(request, response) {
  if (request.method !== 'GET') {
    response.setHeader('Allow', 'GET')
    return response.status(405).json({ error: 'Method not allowed.' })
  }

  const action = request.query.action
  try {
    let data
    if (action === 'leagues') data = await getRackemLeagues()
    else if (action === 'teams') data = await getRackemTeams(request.query.league)
    else if (action === 'team') data = await getRackemTeamPage(request.query.league, request.query.team)
    else return response.status(400).json({ error: 'Unknown RackEm action.' })

    response.setHeader('Cache-Control', CACHE_HEADERS[action] ?? 'no-store')
    return response.status(200).json({ data })
  } catch (error) {
    console.error('RackEm import failed', error)
    return response.status(502).json({ error: error?.message ?? 'RackEm could not be reached.' })
  }
}
