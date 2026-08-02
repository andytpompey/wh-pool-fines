import Foundation
import Observation

@MainActor
@Observable
final class AppCoordinator {
    enum Phase: Equatable {
        case restoring
        case signedOut
        case needsProfile
        case needsTeam
        case ready
        case failed(String)
    }

    private(set) var phase: Phase = .restoring
    private(set) var teams: [TeamOption] = []
    private(set) var selectedTeamID: UUID?
    private(set) var displayName = ""
    private(set) var receiveTeamNotifications = true
    private(set) var dashboardModel = HomeDashboardModel.empty
    private(set) var dashboardError: String?
    private(set) var matchWorkspace = MatchWorkspace.empty
    private(set) var matchesError: String?

    private let authClient: SupabaseAuthClient
    private let teamClient: SupabaseTeamClient
    private let sessionStore: KeychainSessionStore
    private let forceExpiredSession: Bool
    private var authSession: AuthSession?

    init(configuration: RuntimeConfiguration) {
        authClient = SupabaseAuthClient(configuration: configuration)
        teamClient = SupabaseTeamClient(configuration: configuration)
        sessionStore = KeychainSessionStore()
        forceExpiredSession = configuration.forceExpiredSession
    }

    func restore() async {
        if forceExpiredSession {
            phase = .signedOut
            return
        }
        do {
            guard let session = try await sessionStore.load(), !session.isExpired else {
                try? await sessionStore.clear()
                phase = .signedOut
                return
            }
            authSession = session
            try await bootstrap(session)
        } catch let error as RooBinError {
            if error == .unauthenticated {
                await signOut()
            } else {
                phase = .failed(error.localizedDescription)
            }
        } catch let error as LocalizedError {
            phase = .failed(error.errorDescription ?? RooBinError.unexpected.localizedDescription)
        } catch {
            phase = .failed(RooBinError.unexpected.localizedDescription)
        }
    }

    func requestEmailCode(_ email: String) async throws {
        try await authClient.requestEmailCode(email)
    }

    func verifyEmailCode(email: String, code: String) async throws {
        let session = try await authClient.verifyEmailCode(code, email: email)
        try await sessionStore.save(session)
        authSession = session
        try await bootstrap(session)
    }

    func completeProfile(displayName: String) async throws {
        guard let authSession else { throw RooBinError.unauthenticated }
        let profile = try await teamClient.completePlayerProfile(
            displayName: displayName,
            auth: authSession
        )
        self.displayName = profile.displayName
        self.receiveTeamNotifications = profile.receiveTeamNotifications
        try await loadTeams(authSession)
    }

    func updateProfile(displayName: String, receiveTeamNotifications: Bool? = nil) async throws {
        guard let authSession else { throw RooBinError.unauthenticated }
        let profile = try await teamClient.completePlayerProfile(
            displayName: displayName,
            receiveTeamNotifications: receiveTeamNotifications ?? self.receiveTeamNotifications,
            auth: authSession
        )
        self.displayName = profile.displayName
        self.receiveTeamNotifications = profile.receiveTeamNotifications
    }

    func loadAccountDeletionPreflight() async throws -> AccountDeletionPreflight {
        guard let authSession else { throw RooBinError.unauthenticated }
        return try await teamClient.loadAccountDeletionPreflight(auth: authSession)
    }

    func requestAccountDeletionCode(email: String) async throws {
        try await authClient.requestEmailCode(email)
    }

    func deleteAccount(email: String, code: String) async throws {
        guard let existingSession = authSession else { throw RooBinError.unauthenticated }
        let freshSession = try await authClient.verifyEmailCode(code, email: email)
        guard freshSession.userID == existingSession.userID else {
            throw RooBinError.forbidden
        }
        try await sessionStore.save(freshSession)
        authSession = freshSession
        try await teamClient.deleteCurrentAccount(auth: freshSession)
        await signOut()
    }

    func createTeam(name: String) async throws -> TeamOption {
        guard let authSession else { throw RooBinError.unauthenticated }
        let team = try await teamClient.createTeam(name: name, auth: authSession)
        teams.append(team)
        selectTeam(team)
        return team
    }

    func joinTeam(code: String) async throws -> TeamOption {
        guard let authSession else { throw RooBinError.unauthenticated }
        let team = try await teamClient.joinTeam(code: code, auth: authSession)
        teams.append(team)
        selectTeam(team)
        return team
    }

    func selectTeam(_ team: TeamOption) {
        selectedTeamID = team.id
        dashboardModel = emptyDashboard(for: team)
        dashboardError = nil
        matchWorkspace = .empty
        matchesError = nil
        phase = .ready
    }

    func refreshMatches() async {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else { return }
        do {
            matchWorkspace = try await teamClient.loadMatchWorkspace(team: team, auth: authSession)
            matchesError = nil
        } catch let error as LocalizedError {
            matchesError = error.errorDescription ?? RooBinError.unexpected.localizedDescription
        } catch {
            matchesError = RooBinError.unexpected.localizedDescription
        }
    }

    func createMatch(_ draft: MatchDraft) async throws {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else {
            throw RooBinError.unauthenticated
        }
        try await teamClient.createMatch(draft, team: team, auth: authSession)
        await refreshMatches()
        await refreshDashboard()
    }

    func createFineType(name: String, cost: Decimal) async throws {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else {
            throw RooBinError.unauthenticated
        }
        try await teamClient.createFineType(name: name, cost: cost, team: team, auth: authSession)
        await refreshMatches()
    }

    func updateFineType(id:UUID,name:String,cost:Decimal) async throws { guard let authSession,let team=teams.first(where:{$0.id==selectedTeamID}) else { throw RooBinError.unauthenticated };try await teamClient.updateFineType(id:id,name:name,cost:cost,team:team,auth:authSession);await refreshMatches() }
    func deleteFineType(id:UUID,unlockCode:String) async throws { guard let authSession,let team=teams.first(where:{$0.id==selectedTeamID}) else { throw RooBinError.unauthenticated };try await teamClient.deleteManagedEntity(id:id,type:"fine_type",action:"delete_fine_type",unlockCode:unlockCode,team:team,auth:authSession);await refreshMatches() }
    func loadManagedSeasons() async throws -> [ManagedSeason] { guard let authSession,let team=teams.first(where:{$0.id==selectedTeamID}) else { throw RooBinError.unauthenticated };return try await teamClient.loadManagedSeasons(team:team,auth:authSession) }
    func saveSeason(id:UUID,name:String,type:String) async throws { guard let authSession,let team=teams.first(where:{$0.id==selectedTeamID}) else { throw RooBinError.unauthenticated };try await teamClient.saveSeason(id:id,name:name,type:type,team:team,auth:authSession);await refreshMatches();await refreshDashboard() }
    func deleteSeason(id:UUID,unlockCode:String) async throws { guard let authSession,let team=teams.first(where:{$0.id==selectedTeamID}) else { throw RooBinError.unauthenticated };try await teamClient.deleteManagedEntity(id:id,type:"season",action:"delete_season",unlockCode:unlockCode,team:team,auth:authSession);await refreshMatches();await refreshDashboard() }

    func loadCommercialPlayingCycles() async throws -> [CommercialPlayingCycle] {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else { throw RooBinError.unauthenticated }
        return try await teamClient.loadCommercialPlayingCycles(team: team, auth: authSession)
    }

    func beginAppStorePurchase(playingCycleID: UUID) async throws -> AppStorePurchaseContext {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else { throw RooBinError.unauthenticated }
        return try await teamClient.beginAppStorePurchase(playingCycleID: playingCycleID, team: team, auth: authSession)
    }

    func verifyAppStoreTransaction(_ signedTransaction: String) async throws -> AppStoreVerificationResponse {
        guard let authSession else { throw RooBinError.unauthenticated }
        return try await teamClient.verifyAppStoreTransaction(signedTransaction, auth: authSession)
    }

    func invitePlayer(displayName: String, email: String) async throws -> String {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else {
            throw RooBinError.unauthenticated
        }
        return try await teamClient.invitePlayer(
            displayName: displayName,
            email: email,
            team: team,
            auth: authSession
        )
    }

    func addFine(matchID: UUID, playerID: UUID, fineTypeID: UUID) async throws {
        guard let authSession else { throw RooBinError.unauthenticated }
        try await teamClient.addFine(matchID: matchID, playerID: playerID, fineTypeID: fineTypeID, auth: authSession)
        await refreshMatches()
        await refreshDashboard()
    }

    func updateMatchParticipants(matchID: UUID, playerIDs: Set<UUID>, driverIDs: Set<UUID>) async throws {
        guard let authSession else { throw RooBinError.unauthenticated }
        try await teamClient.updateMatchParticipants(
            matchID: matchID, playerIDs: playerIDs, driverIDs: driverIDs, auth: authSession
        )
        await refreshMatches()
        await refreshDashboard()
    }

    func updatePaymentStatus(entries: [LedgerEntry], paid: Bool) async throws {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else {
            throw RooBinError.unauthenticated
        }
        try await teamClient.updatePaymentStatus(entries: entries, paid: paid, team: team, auth: authSession)
        await refreshMatches()
        await refreshDashboard()
    }

    func reassignFine(fineID: UUID, playerID: UUID) async throws {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else {
            throw RooBinError.unauthenticated
        }
        try await teamClient.reassignFine(fineID: fineID, playerID: playerID, team: team, auth: authSession)
        await refreshMatches()
        await refreshDashboard()
    }

    func deleteLedgerEntry(_ entry: LedgerEntry, unlockCode: String) async throws {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else {
            throw RooBinError.unauthenticated
        }
        try await teamClient.deleteLedgerEntry(entry, unlockCode: unlockCode, team: team, auth: authSession)
        await refreshMatches()
        await refreshDashboard()
    }

    func setTeamUnlockCode(_ code: String) async throws {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else {
            throw RooBinError.unauthenticated
        }
        try await teamClient.setTeamUnlockCode(code, team: team, auth: authSession)
        try await loadTeams(authSession)
        await refreshMatches()
        await refreshDashboard()
    }
    func changeTeamUnlockCode(current:String,next:String) async throws {guard let authSession,let team=teams.first(where:{$0.id==selectedTeamID})else{throw RooBinError.unauthenticated};try await teamClient.changeTeamUnlockCode(current:current,next:next,team:team,auth:authSession)}
    func requestUnlockRecoveryCode(email:String) async throws { try await authClient.requestEmailCode(email) }
    func recoverTeamUnlockCode(email:String,code:String) async throws->String {
        guard let existingSession=authSession,let team=teams.first(where:{$0.id==selectedTeamID})else{throw RooBinError.unauthenticated}
        let freshSession=try await authClient.verifyEmailCode(code,email:email)
        guard freshSession.userID==existingSession.userID else{throw RooBinError.forbidden}
        try await sessionStore.save(freshSession);authSession=freshSession
        return try await teamClient.recoverTeamUnlockCode(team:team,auth:freshSession)
    }

    func submitMatch(_ matchID: UUID) async throws {
        guard let authSession else { throw RooBinError.unauthenticated }
        try await teamClient.submitMatch(matchID, auth: authSession)
        await refreshMatches()
        await refreshDashboard()
    }

    func updateMatchFixture(_ draft: MatchFixtureDraft) async throws -> Int64 {
        guard let authSession else { throw RooBinError.unauthenticated }
        let version = try await teamClient.updateMatchFixture(draft, auth: authSession)
        await refreshMatches()
        await refreshDashboard()
        return version
    }

    func loadRoster() async throws -> RosterWorkspace {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else { throw RooBinError.unauthenticated }
        return try await teamClient.loadRoster(team: team, auth: authSession)
    }

    func setMemberRole(_ membershipID: UUID, role: TeamMembershipDTO.Role) async throws {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else { throw RooBinError.unauthenticated }
        try await teamClient.setMemberRole(membershipID, role: role, team: team, auth: authSession)
    }

    func transferCaptain(to membershipID: UUID, from outgoingID: UUID) async throws {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else { throw RooBinError.unauthenticated }
        try await teamClient.transferCaptain(to: membershipID, from: outgoingID, team: team, auth: authSession)
        try await loadTeams(authSession)
    }

    func removeMember(_ membershipID: UUID, unlockCode: String) async throws {
        guard let authSession, let team = teams.first(where: { $0.id == selectedTeamID }) else { throw RooBinError.unauthenticated }
        try await teamClient.removeMember(membershipID, unlockCode: unlockCode, team: team, auth: authSession)
        await refreshMatches()
        await refreshDashboard()
    }

    func resendInvite(_ inviteID: UUID) async throws -> String {
        guard let authSession else { throw RooBinError.unauthenticated }
        return try await teamClient.resendInvite(inviteID, auth: authSession)
    }

    func revokeInvite(_ inviteID: UUID) async throws {
        guard let authSession else { throw RooBinError.unauthenticated }
        try await teamClient.revokeInvite(inviteID, auth: authSession)
    }
    func loadTeamSettings() async throws ->TeamSettingsModel { guard let authSession,let team=teams.first(where:{$0.id==selectedTeamID}) else {throw RooBinError.unauthenticated};return try await teamClient.loadTeamSettings(team:team,auth:authSession) }
    func uploadTeamLogo(_ jpeg:Data) async throws->URL { guard let authSession,let team=teams.first(where:{$0.id==selectedTeamID}) else {throw RooBinError.unauthenticated};return try await teamClient.uploadTeamLogo(jpeg,team:team,auth:authSession) }
    func updateTeamSettings(_ settings:TeamSettingsModel) async throws { guard let authSession,let team=teams.first(where:{$0.id==selectedTeamID}) else {throw RooBinError.unauthenticated};try await teamClient.updateTeamSettings(settings,team:team,auth:authSession);try await loadTeams(authSession);await refreshMatches();await refreshDashboard() }

    func refreshDashboard() async {
        guard
            let authSession,
            let team = teams.first(where: { $0.id == selectedTeamID })
        else { return }
        do {
            let selection = savedSeasonSelection(for: team.id)
            dashboardModel = try await teamClient.loadDashboard(
                team: team,
                selection: selection,
                auth: authSession
            )
            persist(dashboardModel.selectedSeason, for: team.id)
            dashboardError = nil
        } catch let error as LocalizedError {
            dashboardError = error.errorDescription ?? RooBinError.unexpected.localizedDescription
        } catch {
            dashboardError = RooBinError.unexpected.localizedDescription
        }
    }

    func selectDashboardSeason(_ selection: SeasonSelection) async {
        guard let teamID = selectedTeamID else { return }
        persist(selection, for: teamID)
        await refreshDashboard()
    }

    func signOut() async {
        try? await sessionStore.clear()
        authSession = nil
        teams = []
        selectedTeamID = nil
        displayName = ""
        receiveTeamNotifications = true
        dashboardModel = .empty
        dashboardError = nil
        matchWorkspace = .empty
        matchesError = nil
        phase = .signedOut
    }

    func retry() async {
        phase = .restoring
        // Keep the loading state visible long enough to confirm that the retry
        // was accepted, including when a failure is returned immediately.
        try? await Task.sleep(for: .milliseconds(400))
        if let authSession {
            do {
                try await bootstrap(authSession)
            } catch let error as LocalizedError {
                phase = .failed(error.errorDescription ?? RooBinError.unexpected.localizedDescription)
            } catch {
                phase = .failed(RooBinError.unexpected.localizedDescription)
            }
        } else {
            await restore()
        }
    }

    private func bootstrap(_ session: AuthSession) async throws {
        do {
            guard let profile = try await teamClient.loadPlayerProfile(auth: session) else {
                phase = .needsProfile
                return
            }
            displayName = profile.displayName
            receiveTeamNotifications = profile.receiveTeamNotifications
            if profile.profileCompletedAt == nil {
                phase = .needsProfile
                return
            }
            try await loadTeams(session)
        } catch let error as RooBinError {
            if error == .unauthenticated {
                await signOut()
            } else {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func loadTeams(_ session: AuthSession) async throws {
        teams = try await teamClient.loadTeams(auth: session)
        guard let first = teams.first else {
            selectedTeamID = nil
            phase = .needsTeam
            return
        }
        selectedTeamID = teams.contains { $0.id == selectedTeamID } ? selectedTeamID : first.id
        dashboardModel = emptyDashboard(for: teams.first { $0.id == selectedTeamID } ?? first)
        dashboardError = nil
        matchWorkspace = .empty
        matchesError = nil
        phase = .ready
    }

    private func emptyDashboard(for team: TeamOption) -> HomeDashboardModel {
        HomeDashboardModel(
            teamName: team.name,
            teamLogoURL: nil,
            seasons: [],
            selectedSeason: savedSeasonSelection(for: team.id),
            total: 0,
            paid: 0,
            outstanding: 0,
            matchCount: 0,
            fineCount: 0,
            subCount: 0,
            playerBalances: []
        )
    }

    private func savedSeasonSelection(for teamID: UUID) -> SeasonSelection {
        guard
            let value = UserDefaults.standard.string(forKey: "dashboardSeason.\(teamID.uuidString)"),
            let id = UUID(uuidString: value)
        else { return .all }
        return .season(id)
    }

    private func persist(_ selection: SeasonSelection, for teamID: UUID) {
        let key = "dashboardSeason.\(teamID.uuidString)"
        switch selection {
        case .all:
            UserDefaults.standard.removeObject(forKey: key)
        case let .season(id):
            UserDefaults.standard.set(id.uuidString, forKey: key)
        }
    }
}
