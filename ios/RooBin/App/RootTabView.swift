import SwiftUI

struct RootTabView: View {
    let teams: [TeamOption]
    let selectedTeamID: UUID?
    let selectTeam: (TeamOption) -> Void
    let createTeam: (String) async throws -> TeamOption
    let joinTeam: (String) async throws -> TeamOption
    let displayName: String
    let receiveTeamNotifications: Bool
    let updateProfile: (String, Bool) async throws -> Void
    let dashboardModel: HomeDashboardModel
    let dashboardError: String?
    let selectDashboardSeason: (SeasonSelection) async -> Void
    let refreshDashboard: () async -> Void
    let matchWorkspace: MatchWorkspace
    let matchesError: String?
    let refreshMatches: () async -> Void
    let createMatch: (MatchDraft) async throws -> Void
    let createFineType: (String, Decimal) async throws -> Void
    let updateFineType:(UUID,String,Decimal) async throws->Void
    let deleteFineType:(UUID,String) async throws->Void
    let loadSeasons:() async throws->[ManagedSeason]
    let saveSeason:(UUID,String,String) async throws->Void
    let deleteSeason:(UUID,String) async throws->Void
    let loadTeamSettings:() async throws->TeamSettingsModel
    let uploadTeamLogo:(Data) async throws->URL
    let updateTeamSettings:(TeamSettingsModel) async throws->Void
    let invitePlayer: (String, String) async throws -> String
    let addFine: (UUID, UUID, UUID) async throws -> Void
    let updateMatchParticipants: (UUID, Set<UUID>, Set<UUID>) async throws -> Void
    let updatePaymentStatus: ([LedgerEntry], Bool) async throws -> Void
    let reassignFine: (UUID, UUID) async throws -> Void
    let deleteLedgerEntry: (LedgerEntry, String) async throws -> Void
    let setTeamUnlockCode: (String) async throws -> Void
    let changeTeamUnlockCode:(String,String) async throws->Void
    let requestUnlockRecoveryCode:(String) async throws->Void
    let recoverTeamUnlockCode:(String,String) async throws->String
    let submitMatch: (UUID) async throws -> Void
    let updateMatchFixture: (MatchFixtureDraft) async throws -> Int64
    let loadRoster: () async throws -> RosterWorkspace
    let setMemberRole: (UUID, TeamMembershipDTO.Role) async throws -> Void
    let transferCaptain: (UUID, UUID) async throws -> Void
    let removeMember: (UUID, String) async throws -> Void
    let resendInvite: (UUID) async throws -> String
    let revokeInvite: (UUID) async throws -> Void
    let loadAccountDeletionPreflight: () async throws -> AccountDeletionPreflight
    let requestAccountDeletionCode: (String) async throws -> Void
    let deleteAccount: (String, String) async throws -> Void
    let signOut: () async -> Void

    var body: some View {
        TabView {
            HomeDashboardView(
                model: dashboardModel,
                errorMessage: dashboardError,
                selectSeason: { selection in
                    Task { await selectDashboardSeason(selection) }
                },
                refresh: refreshDashboard
            )
            .task(id: selectedTeamID) { await refreshDashboard() }
            .rooBinBrandHeader(teamName: headerTeamName, teamLogoURL: dashboardModel.teamLogoURL)
            .tabItem {
                Label("Home", systemImage: "house")
            }

            MatchListView(
                matches: matchWorkspace.matches,
                seasons: matchWorkspace.seasons,
                players: matchWorkspace.players,
                fineTypes: matchWorkspace.fineTypes,
                activity: matchWorkspace.activity,
                canCreate: selectedTeam?.role == .captain || selectedTeam?.role == .viceCaptain,
                errorMessage: matchesError,
                refresh: refreshMatches,
                createMatch: createMatch,
                addFine: addFine,
                updateMatchParticipants: updateMatchParticipants,
                reassignFine: reassignFine,
                deleteEntry: deleteLedgerEntry,
                submitMatch: submitMatch,
                updateMatchFixture: updateMatchFixture
            )
            .task(id: selectedTeamID) { await refreshMatches() }
            .rooBinBrandHeader(teamName: headerTeamName, teamLogoURL: dashboardModel.teamLogoURL)
            .tabItem {
                Label("Matches", systemImage: "list.bullet.clipboard")
            }

            FinesLedgerView(
                entries: matchWorkspace.ledgerEntries,
                seasons: matchWorkspace.seasons,
                players: matchWorkspace.players,
                activity: matchWorkspace.activity,
                canManagePayments: selectedTeam?.role == .captain || selectedTeam?.role == .viceCaptain,
                updatePaymentStatus: updatePaymentStatus,
                reassignFine: reassignFine,
                deleteEntry: deleteLedgerEntry,
                refresh: refreshMatches
            )
            .task(id: selectedTeamID) { await refreshMatches() }
            .rooBinBrandHeader(teamName: headerTeamName, teamLogoURL: dashboardModel.teamLogoURL)
            .tabItem {
                Label("Fines", systemImage: "sterlingsign.circle")
            }

            SettingsView(
                teams: teams,
                selectedTeamID: selectedTeamID,
                selectTeam: selectTeam,
                createTeam: createTeam,
                joinTeam: joinTeam,
                displayName: displayName,
                receiveTeamNotifications: receiveTeamNotifications,
                updateProfile: updateProfile,
                fineTypes: matchWorkspace.fineTypes,
                canManageTeam: selectedTeam?.role == .captain || selectedTeam?.role == .viceCaptain,
                createFineType: createFineType,
                updateFineType:updateFineType,deleteFineType:deleteFineType,loadSeasons:loadSeasons,saveSeason:saveSeason,deleteSeason:deleteSeason,
                loadTeamSettings:loadTeamSettings,uploadTeamLogo:uploadTeamLogo,updateTeamSettings:updateTeamSettings,
                invitePlayer: invitePlayer,
                setTeamUnlockCode: setTeamUnlockCode,
                changeTeamUnlockCode:changeTeamUnlockCode,requestUnlockRecoveryCode:requestUnlockRecoveryCode,recoverTeamUnlockCode:recoverTeamUnlockCode,
                loadRoster: loadRoster,
                setMemberRole: setMemberRole,
                transferCaptain: transferCaptain,
                removeMember: removeMember,
                resendInvite: resendInvite,
                revokeInvite: revokeInvite,
                loadAccountDeletionPreflight: loadAccountDeletionPreflight,
                requestAccountDeletionCode: requestAccountDeletionCode,
                deleteAccount: deleteAccount,
                signOut: signOut
            )
            .rooBinBrandHeader(teamName: headerTeamName, teamLogoURL: dashboardModel.teamLogoURL)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(RooBinTheme.Colors.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootTabView(
        teams: [],
        selectedTeamID: nil,
        selectTeam: { _ in },
        createTeam: { _ in throw RooBinError.serviceUnavailable },
        joinTeam: { _ in throw RooBinError.serviceUnavailable },
        displayName: "Test Player",
        receiveTeamNotifications: true,
        updateProfile: { _, _ in },
        dashboardModel: .empty,
        dashboardError: nil,
        selectDashboardSeason: { _ in },
        refreshDashboard: {},
        matchWorkspace: .empty,
        matchesError: nil,
        refreshMatches: {},
        createMatch: { _ in },
        createFineType: { _, _ in },
        updateFineType:{_,_,_ in},deleteFineType:{_,_ in},loadSeasons:{[]},saveSeason:{_,_,_ in},deleteSeason:{_,_ in},
        loadTeamSettings:{TeamSettingsModel(name:"Team",subsEnabled:true,driversVoidSubs:true,subAmount:0.5,logoURL:nil)},uploadTeamLogo:{_ in throw RooBinError.serviceUnavailable},updateTeamSettings:{_ in},
        invitePlayer: { _, _ in "Invite sent." },
        addFine: { _, _, _ in },
        updateMatchParticipants: { _, _, _ in },
        updatePaymentStatus: { _, _ in },
        reassignFine: { _, _ in },
        deleteLedgerEntry: { _, _ in },
        setTeamUnlockCode: { _ in },
        changeTeamUnlockCode:{_,_ in},requestUnlockRecoveryCode:{_ in},recoverTeamUnlockCode:{_,_ in "Recovery sent."},
        submitMatch: { _ in },
        updateMatchFixture: { _ in 1 },
        loadRoster: { RosterWorkspace(members: [], invites: []) },
        setMemberRole: { _, _ in },
        transferCaptain: { _, _ in },
        removeMember: { _, _ in },
        resendInvite: { _ in "Invite sent." },
        revokeInvite: { _ in },
        loadAccountDeletionPreflight: { throw RooBinError.serviceUnavailable },
        requestAccountDeletionCode: { _ in },
        deleteAccount: { _, _ in },
        signOut: {}
    )
}

private extension RootTabView {
    var selectedTeam: TeamOption? {
        teams.first { $0.id == selectedTeamID }
    }

    var headerTeamName: String? {
        selectedTeam?.name ?? (dashboardModel.teamName.isEmpty ? nil : dashboardModel.teamName)
    }
}
