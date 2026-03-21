export function resolveCurrentTeamContext({ routeTeamId = null, storedTeamId = null, memberships = [] }) {
  const availableTeamIds = memberships.map(membership => membership.team.id)

  if (routeTeamId && availableTeamIds.includes(routeTeamId)) return routeTeamId
  if (storedTeamId && availableTeamIds.includes(storedTeamId)) return storedTeamId
  return availableTeamIds[0] ?? null
}
