import SwiftUI

struct AppRootView: View {
    @State private var coordinator: AppCoordinator?
    private let configurationError: String?

    init() {
        do {
            let configuration = try RuntimeConfiguration.load()
            _coordinator = State(initialValue: AppCoordinator(configuration: configuration))
            configurationError = nil
        } catch let error as LocalizedError {
            _coordinator = State(initialValue: nil)
            configurationError = error.errorDescription
        } catch {
            _coordinator = State(initialValue: nil)
            configurationError = RooBinError.unexpected.localizedDescription
        }
    }

    var body: some View {
        Group {
            if let coordinator {
                content(for: coordinator)
            } else {
                failureView(configurationError ?? RooBinError.unexpected.localizedDescription)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(for coordinator: AppCoordinator) -> some View {
        switch coordinator.phase {
        case .restoring:
            ProgressView("Loading RooBin…")
                .task { await coordinator.restore() }

        case .signedOut:
            AuthenticationFlowView(
                requestEmailCode: { email in
                    try await coordinator.requestEmailCode(email)
                },
                verifyEmailCode: { email, code in
                    try await coordinator.verifyEmailCode(email: email, code: code)
                }
            )

        case .needsProfile:
            NavigationStack {
                ProfileCompletionView(displayName: coordinator.displayName) { displayName in
                    try await coordinator.completeProfile(displayName: displayName)
                }
            }

        case .needsTeam:
            TeamOnboardingView(
                createTeam: { name in try await coordinator.createTeam(name: name) },
                joinTeam: { code in try await coordinator.joinTeam(code: code) },
                selectTeam: coordinator.selectTeam
            )

        case .ready:
            RootTabView(
                teams: coordinator.teams,
                selectedTeamID: coordinator.selectedTeamID,
                selectTeam: coordinator.selectTeam,
                createTeam: { name in try await coordinator.createTeam(name: name) },
                joinTeam: { code in try await coordinator.joinTeam(code: code) },
                displayName: coordinator.displayName,
                receiveTeamNotifications: coordinator.receiveTeamNotifications,
                updateProfile: { name, notifications in
                    try await coordinator.updateProfile(
                        displayName: name,
                        receiveTeamNotifications: notifications
                    )
                },
                dashboardModel: coordinator.dashboardModel,
                dashboardError: coordinator.dashboardError,
                selectDashboardSeason: { selection in
                    await coordinator.selectDashboardSeason(selection)
                },
                refreshDashboard: { await coordinator.refreshDashboard() },
                matchWorkspace: coordinator.matchWorkspace,
                matchesError: coordinator.matchesError,
                refreshMatches: { await coordinator.refreshMatches() },
                createMatch: { draft in try await coordinator.createMatch(draft) },
                createFineType: { name, cost in
                    try await coordinator.createFineType(name: name, cost: cost)
                },
                updateFineType:{id,name,cost in try await coordinator.updateFineType(id:id,name:name,cost:cost)},
                deleteFineType:{id,code in try await coordinator.deleteFineType(id:id,unlockCode:code)},
                loadSeasons:{try await coordinator.loadManagedSeasons()},
                saveSeason:{id,name,type in try await coordinator.saveSeason(id:id,name:name,type:type)},
                deleteSeason:{id,code in try await coordinator.deleteSeason(id:id,unlockCode:code)},
                loadCommercialPlayingCycles: { try await coordinator.loadCommercialPlayingCycles() },
                beginAppStorePurchase: { cycleID in try await coordinator.beginAppStorePurchase(playingCycleID: cycleID) },
                verifyAppStoreTransaction: { signedTransaction in try await coordinator.verifyAppStoreTransaction(signedTransaction) },
                loadTeamSettings:{try await coordinator.loadTeamSettings()},
                uploadTeamLogo:{data in try await coordinator.uploadTeamLogo(data)},
                updateTeamSettings:{settings in try await coordinator.updateTeamSettings(settings)},
                invitePlayer: { name, email in
                    try await coordinator.invitePlayer(displayName: name, email: email)
                },
                addFine: { matchID, playerID, fineTypeID in
                    try await coordinator.addFine(matchID: matchID, playerID: playerID, fineTypeID: fineTypeID)
                },
                updateMatchParticipants: { matchID, playerIDs, driverIDs in
                    try await coordinator.updateMatchParticipants(
                        matchID: matchID, playerIDs: playerIDs, driverIDs: driverIDs
                    )
                },
                updatePaymentStatus: { entries, paid in
                    try await coordinator.updatePaymentStatus(entries: entries, paid: paid)
                },
                reassignFine: { fineID, playerID in
                    try await coordinator.reassignFine(fineID: fineID, playerID: playerID)
                },
                deleteLedgerEntry: { entry, unlockCode in
                    try await coordinator.deleteLedgerEntry(entry, unlockCode: unlockCode)
                },
                setTeamUnlockCode: { code in
                    try await coordinator.setTeamUnlockCode(code)
                },
                changeTeamUnlockCode:{current,next in try await coordinator.changeTeamUnlockCode(current:current,next:next)},
                requestUnlockRecoveryCode:{email in try await coordinator.requestUnlockRecoveryCode(email:email)},
                recoverTeamUnlockCode:{email,code in try await coordinator.recoverTeamUnlockCode(email:email,code:code)},
                submitMatch: { matchID in
                    try await coordinator.submitMatch(matchID)
                },
                updateMatchFixture: { draft in
                    try await coordinator.updateMatchFixture(draft)
                },
                loadRoster: { try await coordinator.loadRoster() },
                setMemberRole: { membershipID, role in
                    try await coordinator.setMemberRole(membershipID, role: role)
                },
                transferCaptain: { incomingID, outgoingID in
                    try await coordinator.transferCaptain(to: incomingID, from: outgoingID)
                },
                removeMember: { membershipID, unlockCode in
                    try await coordinator.removeMember(membershipID, unlockCode: unlockCode)
                },
                resendInvite: { inviteID in try await coordinator.resendInvite(inviteID) },
                revokeInvite: { inviteID in try await coordinator.revokeInvite(inviteID) },
                loadAccountDeletionPreflight: { try await coordinator.loadAccountDeletionPreflight() },
                requestAccountDeletionCode: { email in
                    try await coordinator.requestAccountDeletionCode(email: email)
                },
                deleteAccount: { email, code in
                    try await coordinator.deleteAccount(email: email, code: code)
                },
                signOut: { await coordinator.signOut() }
            )

        case let .failed(message):
            failureView(message) {
                Task { await coordinator.retry() }
            }
        }
    }

    private func failureView(
        _ message: String,
        retry: (() -> Void)? = nil
    ) -> some View {
        ContentUnavailableView {
            Label("Unable to load RooBin", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("Try again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("Authentication") {
    AppRootView()
}
