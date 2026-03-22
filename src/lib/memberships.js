import * as userProfileDb from './userProfile'
import * as teamModel from './teamModel'
import * as platformAccess from './platformAccess'

export async function resolveAuthenticatedPlayerContext({ user }) {
  if (!user?.id) {
    return { profile: null, player: null, memberships: [], platformRole: null, isPlatformAdmin: false }
  }

  const profile = await userProfileDb.upsertCurrentUserProfile({ user })
  if (!profile?.playerId) {
    return { profile, player: null, memberships: [], platformRole: null, isPlatformAdmin: false }
  }

  const [{ platformRole, isPlatformAdmin }, memberships] = await Promise.all([
    platformAccess.getPlatformAccess(user.id),
    teamModel.listMembershipsForPlayer(profile.playerId),
  ])
  const membershipsWithCounts = await Promise.all(memberships.map(async membership => ({
    ...membership,
    playerId: profile.playerId,
    team: {
      ...membership.team,
      memberCount: await teamModel.getTeamMembershipCount(membership.team.id),
    },
  })))

  return {
    profile,
    player: {
      id: profile.playerId,
      name: profile.displayName ?? profile.email ?? profile.mobile ?? 'Current player',
      email: profile.email,
    },
    memberships: membershipsWithCounts,
    platformRole,
    isPlatformAdmin,
  }
}
