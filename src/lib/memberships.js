import * as userProfileDb from './userProfile'
import * as teamModel from './teamModel'

export async function resolveAuthenticatedPlayerContext({ user }) {
  if (!user?.id) {
    return { profile: null, player: null, memberships: [] }
  }

  const profile = await userProfileDb.upsertCurrentUserProfile({ user })
  if (!profile?.playerId) {
    return { profile, player: null, memberships: [] }
  }

  const memberships = await teamModel.listMembershipsForPlayer(profile.playerId)

  return {
    profile,
    player: {
      id: profile.playerId,
      name: profile.displayName ?? profile.email ?? profile.mobile ?? 'Current player',
    },
    memberships,
  }
}
