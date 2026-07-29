async function rackemRequest(params) {
  const response = await fetch(`/api/rackem?${new URLSearchParams(params)}`)
  const body = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(body?.error || 'RackEm could not be reached.')
  return body.data
}

export const listRackemLeagues = () => rackemRequest({ action: 'leagues' })

export const listRackemTeams = leagueSlug =>
  rackemRequest({ action: 'teams', league: leagueSlug })

export const getRackemTeamPage = (leagueSlug, seasonTeamId) =>
  rackemRequest({ action: 'team', league: leagueSlug, team: seasonTeamId })
