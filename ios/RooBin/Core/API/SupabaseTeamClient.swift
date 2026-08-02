import Foundation
import OSLog

actor SupabaseTeamClient {
    private static let logger = Logger(
        subsystem: "com.roobin.app",
        category: "BackendContract"
    )

    private struct BackendError: Decodable {
        let code: String?
        let message: String?
    }

    struct PlayerProfile: Equatable, Sendable, Decodable {
        let id: UUID
        let displayName: String
        let receiveTeamNotifications: Bool
        let profileCompletedAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case receiveTeamNotifications = "receive_team_notifications"
            case profileCompletedAt = "profile_completed_at"
        }
    }

    private struct TeamRow: Decodable {
        let id: UUID
        let name: String
        let unlockCodeResetRequired: Bool?

        enum CodingKeys: String, CodingKey {
            case id, name
            case unlockCodeResetRequired = "unlock_code_reset_required"
        }
    }

    private struct MembershipRow: Decodable {
        let role: TeamMembershipDTO.Role
        let teams: TeamRow
    }

    private struct DashboardMembershipRow: Decodable {
        let players: DashboardPlayerRow
    }

    private struct DashboardPlayerRow: Decodable {
        let id: UUID
        let name: String
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case id, name
            case displayName = "display_name"
        }
    }

    private struct RosterMembershipRow: Decodable {
        struct Player: Decodable {
            let id: UUID
            let name: String
            let displayName: String?
            let email: String
            enum CodingKeys: String, CodingKey {
                case id, name, email
                case displayName = "display_name"
            }
        }
        let id: UUID
        let role: TeamMembershipDTO.Role
        let players: Player
    }

    private struct InviteRow: Decodable {
        let id: UUID
        let email: String
        let expiresAt: String?
        enum CodingKeys: String, CodingKey {
            case id, email
            case expiresAt = "expires_at"
        }
    }

    private struct SeasonRow: Decodable {
        let id: UUID
        let name: String
    }

    private struct MatchRow: Decodable {
        let id: UUID
        let date: String
        let seasonID: UUID?
        let opponent: String?
        let venue: MatchSummary.Venue
        let submitted: Bool
        let editVersion: Int64

        enum CodingKeys: String, CodingKey {
            case id, date, opponent, venue, submitted
            case seasonID = "season_id"
            case editVersion = "edit_version"
        }
    }

    private struct MatchPlayerRow: Decodable {
        let matchID: UUID
        let playerID: UUID
        let isDriver: Bool

        enum CodingKeys: String, CodingKey {
            case matchID = "match_id"
            case playerID = "player_id"
            case isDriver = "is_driver"
        }
    }

    private struct TeamSettingsRow: Decodable {
        let subsEnabled: Bool
        let driversVoidSubs: Bool
        let subAmount: Decimal

        enum CodingKeys: String, CodingKey {
            case subsEnabled = "subs_enabled"
            case driversVoidSubs = "drivers_void_subs"
            case subAmount = "sub_amount"
        }
    }

    private struct SaveMatchBody: Encodable {
        struct Aggregate: Encodable {
            struct Player: Encodable {
                let playerID: UUID
                let isDriver: Bool
                enum CodingKeys: String, CodingKey {
                    case playerID = "playerId"
                    case isDriver
                }
            }

            struct Sub: Encodable {
                let id: UUID
                let playerID: UUID
                let playerName: String
                let amount: Decimal
                let paid: Bool
                enum CodingKeys: String, CodingKey {
                    case id, amount, paid
                    case playerID = "playerId"
                    case playerName
                }
            }

            let id: UUID
            let teamID: UUID
            let date: String
            let seasonID: UUID?
            let opponent: String
            let submitted = false
            let venue: String
            let players: [Player]
            let fines: [String] = []
            let subs: [Sub]

            enum CodingKeys: String, CodingKey {
                case id, date, opponent, submitted, venue, players, fines, subs
                case teamID = "teamId"
                case seasonID = "seasonId"
            }
        }

        let operationID: UUID
        let aggregate: Aggregate

        enum CodingKeys: String, CodingKey {
            case operationID = "operation_id"
            case aggregate
        }
    }

    private struct FineRow: Decodable {
        let id: UUID
        let matchID: UUID
        let playerID: UUID?
        let playerName: String
        let fineName: String
        let cost: Decimal
        let paid: Bool

        enum CodingKeys: String, CodingKey {
            case id, cost, paid
            case matchID = "match_id"
            case playerID = "player_id"
            case playerName = "player_name"
            case fineName = "fine_name"
        }
    }

    private struct SubRow: Decodable {
        let id: UUID
        let matchID: UUID
        let playerID: UUID?
        let playerName: String
        let amount: Decimal
        let paid: Bool

        enum CodingKeys: String, CodingKey {
            case id, amount, paid
            case matchID = "match_id"
            case playerID = "player_id"
            case playerName = "player_name"
        }
    }

    private struct EnsurePlayerBody: Encodable {
        let profileDisplayName: String
        let profileMobile: String? = nil
        let profilePreferredAuthMethod = "email"

        enum CodingKeys: String, CodingKey {
            case profileDisplayName = "profile_display_name"
            case profileMobile = "profile_mobile"
            case profilePreferredAuthMethod = "profile_preferred_auth_method"
        }
    }

    private struct CreateTeamBody: Encodable {
        let teamName: String
        let requestedJoinCode: String? = nil

        enum CodingKeys: String, CodingKey {
            case teamName = "team_name"
            case requestedJoinCode = "requested_join_code"
        }
    }

    private struct JoinTeamBody: Encodable {
        let requestedJoinCode: String

        enum CodingKeys: String, CodingKey {
            case requestedJoinCode = "requested_join_code"
        }
    }

    private let configuration: RuntimeConfiguration
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: RuntimeConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func loadPlayerProfile(auth: AuthSession) async throws -> PlayerProfile? {
        let path = "rest/v1/players?select=id,display_name,receive_team_notifications,profile_completed_at&user_id=eq.\(auth.userID.uuidString)&limit=1"
        let data = try await perform(path: path, method: "GET", body: nil, auth: auth)
        return try decoder.decode([PlayerProfile].self, from: data).first
    }

    func loadAccountDeletionPreflight(auth: AuthSession) async throws -> AccountDeletionPreflight {
        let data = try await perform(
            path: "rest/v1/rpc/account_deletion_preflight",
            method: "POST",
            body: Data("{}".utf8),
            auth: auth
        )
        return try decoder.decode(AccountDeletionPreflight.self, from: data)
    }

    func deleteCurrentAccount(auth: AuthSession) async throws {
        _ = try await perform(
            path: "functions/v1/account-deletion",
            method: "POST",
            body: Data("{}".utf8),
            auth: auth
        )
    }

    func ensurePlayer(displayName: String, auth: AuthSession) async throws {
        let body = try encoder.encode(EnsurePlayerBody(profileDisplayName: displayName))
        _ = try await perform(
            path: "rest/v1/rpc/ensure_current_player",
            method: "POST",
            body: body,
            auth: auth
        )
    }

    func completePlayerProfile(
        displayName: String,
        receiveTeamNotifications: Bool = true,
        auth: AuthSession
    ) async throws -> PlayerProfile {
        if try await loadPlayerProfile(auth: auth) == nil {
            try await ensurePlayer(displayName: displayName, auth: auth)
        }
        struct UpdateBody: Encodable {
            let profileDisplayName: String
            let profileReceiveTeamNotifications: Bool
            enum CodingKeys: String, CodingKey {
                case profileDisplayName = "profile_display_name"
                case profileReceiveTeamNotifications = "profile_receive_team_notifications"
            }
        }
        let body = try encoder.encode(
            UpdateBody(
                profileDisplayName: displayName,
                profileReceiveTeamNotifications: receiveTeamNotifications
            )
        )
        let data = try await perform(
            path: "rest/v1/rpc/update_current_player_profile",
            method: "POST",
            body: body,
            auth: auth
        )
        return try decoder.decode(PlayerProfile.self, from: data)
    }

    func loadTeams(auth: AuthSession) async throws -> [TeamOption] {
        let path = "rest/v1/team_memberships?select=role,teams(id,name,unlock_code_reset_required)&status=eq.active"
        let data = try await perform(path: path, method: "GET", body: nil, auth: auth)
        return try decoder.decode([MembershipRow].self, from: data).map {
            TeamOption(
                id: $0.teams.id,
                name: $0.teams.name,
                role: $0.role,
                unlockCodeResetRequired: $0.teams.unlockCodeResetRequired ?? true
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func createTeam(name: String, auth: AuthSession) async throws -> TeamOption {
        let body = try encoder.encode(CreateTeamBody(teamName: name))
        let data = try await perform(
            path: "rest/v1/rpc/create_team_with_captain",
            method: "POST",
            body: body,
            auth: auth
        )
        let team = try decoder.decode(TeamRow.self, from: data)
        return TeamOption(
            id: team.id, name: team.name, role: .captain,
            unlockCodeResetRequired: team.unlockCodeResetRequired ?? true
        )
    }

    func joinTeam(code: String, auth: AuthSession) async throws -> TeamOption {
        let body = try encoder.encode(JoinTeamBody(requestedJoinCode: code))
        let data = try await perform(
            path: "rest/v1/rpc/join_team_by_code",
            method: "POST",
            body: body,
            auth: auth
        )
        let team = try decoder.decode(TeamRow.self, from: data)
        return TeamOption(
            id: team.id, name: team.name, role: .member,
            unlockCodeResetRequired: team.unlockCodeResetRequired ?? true
        )
    }

    func setTeamUnlockCode(_ code: String, team: TeamOption, auth: AuthSession) async throws {
        struct Body: Encodable {
            let targetTeamID: UUID
            let newUnlockCode: String
            enum CodingKeys: String, CodingKey {
                case targetTeamID = "target_team_id"
                case newUnlockCode = "new_unlock_code"
            }
        }
        _ = try await perform(
            path: "rest/v1/rpc/set_team_unlock_code",
            method: "POST",
            body: try encoder.encode(Body(targetTeamID: team.id, newUnlockCode: code)),
            auth: auth
        )
    }
    func changeTeamUnlockCode(current:String,next:String,team:TeamOption,auth:AuthSession) async throws {
        struct V:Encodable {let targetTeamID:UUID;let protectedAction="change_unlock_code";let suppliedUnlockCode:String;enum CodingKeys:String,CodingKey{case targetTeamID="target_team_id",protectedAction="protected_action",suppliedUnlockCode="supplied_unlock_code"}}
        struct R:Decodable{let authorized:Bool;let grantToken:UUID?;let reason:String?}
        struct C:Encodable{let grantToken:UUID;let newUnlockCode:String;enum CodingKeys:String,CodingKey{case grantToken="grant_token",newUnlockCode="new_unlock_code"}}
        let data=try await perform(path:"rest/v1/rpc/verify_team_unlock_code",method:"POST",body:try encoder.encode(V(targetTeamID:team.id,suppliedUnlockCode:current)),auth:auth);let v=try decoder.decode(R.self,from:data)
        guard v.authorized,let token=v.grantToken else{if v.reason=="rate_limited"{throw RooBinError.rateLimited};throw RooBinError.validation(message:"The current unlock code is incorrect.")}
        _=try await perform(path:"rest/v1/rpc/change_team_unlock_code",method:"POST",body:try encoder.encode(C(grantToken:token,newUnlockCode:next)),auth:auth)
    }
    func recoverTeamUnlockCode(team:TeamOption,auth:AuthSession) async throws->String {
        struct B:Encodable{let action="reset-unlock-code";let teamID:UUID;let reason="captain_recovery";enum CodingKeys:String,CodingKey{case action,reason;case teamID="teamId"}}
        struct R:Decodable{let message:String}
        let data=try await perform(path:"functions/v1/team-communications",method:"POST",body:try encoder.encode(B(teamID:team.id)),auth:auth);return try decoder.decode(R.self,from:data).message
    }

    func loadRoster(team: TeamOption, auth: AuthSession) async throws -> RosterWorkspace {
        let memberData = try await perform(
            path: "rest/v1/team_memberships?select=id,role,players(id,name,display_name,email)&team_id=eq.\(team.id)&status=eq.active",
            method: "GET", body: nil, auth: auth
        )
        let inviteData = try await perform(
            path: "rest/v1/team_invites?select=id,email,expires_at&team_id=eq.\(team.id)&status=eq.pending&order=created_at.desc",
            method: "GET", body: nil, auth: auth
        )
        let formatter = ISO8601DateFormatter()
        return RosterWorkspace(
            members: try decoder.decode([RosterMembershipRow].self, from: memberData).map {
                RosterMember(
                    id: $0.id, playerID: $0.players.id,
                    name: $0.players.displayName ?? $0.players.name,
                    email: $0.players.email, role: $0.role
                )
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            invites: try decoder.decode([InviteRow].self, from: inviteData).map {
                PendingTeamInvite(id: $0.id, email: $0.email, expiresAt: $0.expiresAt.flatMap(formatter.date))
            }
        )
    }

    func loadTeamSettings(team:TeamOption,auth:AuthSession) async throws -> TeamSettingsModel {
        struct Row:Decodable { let name:String;let subsEnabled:Bool;let driversVoidSubs:Bool;let subAmount:Decimal;let logoURL:URL?
            enum CodingKeys:String,CodingKey { case name;case subsEnabled="subs_enabled",driversVoidSubs="drivers_void_subs",subAmount="sub_amount",logoURL="logo_url" } }
        let data=try await perform(path:"rest/v1/teams?select=name,subs_enabled,drivers_void_subs,sub_amount,logo_url&id=eq.\(team.id)&limit=1",method:"GET",body:nil,auth:auth)
        guard let r=try decoder.decode([Row].self,from:data).first else { throw RooBinError.notFound }
        return TeamSettingsModel(name:r.name,subsEnabled:r.subsEnabled,driversVoidSubs:r.driversVoidSubs,subAmount:r.subAmount,logoURL:r.logoURL)
    }

    func uploadTeamLogo(_ jpeg:Data,team:TeamOption,auth:AuthSession) async throws -> URL {
        let objectPath = Self.teamLogoObjectPath(teamID: team.id, versionID: UUID())
        guard jpeg.count<=1_048_576,let url=URL(string:"storage/v1/object/team-logos/\(objectPath)",relativeTo:configuration.supabaseURL) else { throw RooBinError.validation(message:"The processed logo must be smaller than 1 MB.") }
        var request=URLRequest(url:url,cachePolicy:.reloadIgnoringLocalAndRemoteCacheData,timeoutInterval:30);request.httpMethod="POST";request.httpBody=jpeg
        request.setValue("image/jpeg",forHTTPHeaderField:"Content-Type");request.setValue("true",forHTTPHeaderField:"x-upsert");request.setValue(configuration.supabasePublishableKey,forHTTPHeaderField:"apikey");request.setValue("Bearer \(auth.accessToken)",forHTTPHeaderField:"Authorization")
        request.setValue("public, max-age=31536000, immutable",forHTTPHeaderField:"Cache-Control")
        let (_,response)=try await session.data(for:request);guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode) else { throw RooBinError.serviceUnavailable }
        if configuration.pauseAfterLogoUpload {
            try await Task.sleep(for: .seconds(60))
        }
        guard let publicURL=URL(string:"storage/v1/object/public/team-logos/\(objectPath)",relativeTo:configuration.supabaseURL),
              var components=URLComponents(url:publicURL,resolvingAgainstBaseURL:true) else { throw RooBinError.unexpected }
        components.queryItems=[URLQueryItem(name:"v",value:UUID().uuidString.lowercased())]
        guard let versionedURL=components.url else { throw RooBinError.unexpected }
        return versionedURL
    }

    nonisolated static func teamLogoObjectPath(teamID: UUID, versionID: UUID) -> String {
        "\(teamID.uuidString.lowercased())/logo-\(versionID.uuidString.lowercased()).jpg"
    }

    func updateTeamSettings(_ settings:TeamSettingsModel,team:TeamOption,auth:AuthSession) async throws {
        struct Body:Encodable { let operationID=UUID();let targetTeamID:UUID;let teamName:String;let useSubs:Bool;let voidDriverSubs:Bool;let configuredSubAmount:Decimal;let configuredLogoURL:String?
            enum CodingKeys:String,CodingKey { case operationID="operation_id",targetTeamID="target_team_id",teamName="team_name",useSubs="use_subs",voidDriverSubs="void_driver_subs",configuredSubAmount="configured_sub_amount",configuredLogoURL="configured_logo_url" } }
        let body=Body(targetTeamID:team.id,teamName:settings.name,useSubs:settings.subsEnabled,voidDriverSubs:settings.driversVoidSubs,configuredSubAmount:settings.subAmount,configuredLogoURL:settings.logoURL?.absoluteString)
        _=try await perform(path:"rest/v1/rpc/update_team_settings",method:"POST",body:try encoder.encode(body),auth:auth)
    }

    func setMemberRole(_ membershipID: UUID, role: TeamMembershipDTO.Role, team: TeamOption, auth: AuthSession) async throws {
        struct Body: Encodable {
            let operationID = UUID(); let targetTeamID: UUID; let targetMembershipID: UUID; let nextRole: String
            enum CodingKeys: String, CodingKey {
                case operationID = "operation_id"; case targetTeamID = "target_team_id"
                case targetMembershipID = "target_membership_id"; case nextRole = "next_role"
            }
        }
        _ = try await perform(path: "rest/v1/rpc/set_team_member_role", method: "POST", body: try encoder.encode(Body(targetTeamID: team.id, targetMembershipID: membershipID, nextRole: role.rawValue)), auth: auth)
    }

    func transferCaptain(to membershipID: UUID, from outgoingID: UUID, team: TeamOption, auth: AuthSession) async throws {
        struct Body: Encodable {
            let operationID = UUID(); let targetTeamID: UUID; let incomingMembershipID: UUID; let outgoingMembershipID: UUID
            enum CodingKeys: String, CodingKey {
                case operationID = "operation_id"; case targetTeamID = "target_team_id"
                case incomingMembershipID = "incoming_membership_id"; case outgoingMembershipID = "outgoing_membership_id"
            }
        }
        _ = try await perform(path: "rest/v1/rpc/transfer_team_captain", method: "POST", body: try encoder.encode(Body(targetTeamID: team.id, incomingMembershipID: membershipID, outgoingMembershipID: outgoingID)), auth: auth)
    }

    func resendInvite(_ inviteID: UUID, auth: AuthSession) async throws -> String {
        struct Body: Encodable { let action = "resend"; let inviteID: UUID; enum CodingKeys: String, CodingKey { case action; case inviteID = "inviteId" } }
        struct Response: Decodable { let message: String }
        let data = try await perform(path: "functions/v1/team-communications", method: "POST", body: try encoder.encode(Body(inviteID: inviteID)), auth: auth)
        return try decoder.decode(Response.self, from: data).message
    }

    func revokeInvite(_ inviteID: UUID, auth: AuthSession) async throws {
        struct Body: Encodable { let targetInviteID: UUID; enum CodingKeys: String, CodingKey { case targetInviteID = "target_invite_id" } }
        _ = try await perform(path: "rest/v1/rpc/revoke_team_invite", method: "POST", body: try encoder.encode(Body(targetInviteID: inviteID)), auth: auth)
    }

    func removeMember(_ membershipID: UUID, unlockCode: String, team: TeamOption, auth: AuthSession) async throws {
        struct VerifyBody: Encodable {
            let targetTeamID: UUID; let protectedAction = "remove_team_member"; let suppliedUnlockCode: String
            enum CodingKeys: String, CodingKey {
                case targetTeamID = "target_team_id"; case protectedAction = "protected_action"; case suppliedUnlockCode = "supplied_unlock_code"
            }
        }
        struct VerifyResponse: Decodable { let authorized: Bool; let grantToken: UUID?; let reason: String? }
        struct ExecuteBody: Encodable {
            let grantToken: UUID; let targetEntityType = "team_membership"; let targetEntityID: UUID
            enum CodingKeys: String, CodingKey {
                case grantToken = "grant_token"; case targetEntityType = "target_entity_type"; case targetEntityID = "target_entity_id"
            }
        }
        let data = try await perform(path: "rest/v1/rpc/verify_team_unlock_code", method: "POST", body: try encoder.encode(VerifyBody(targetTeamID: team.id, suppliedUnlockCode: unlockCode)), auth: auth)
        let verification = try decoder.decode(VerifyResponse.self, from: data)
        guard verification.authorized, let token = verification.grantToken else {
            if verification.reason == "rate_limited" {
                throw RooBinError.validation(message: "Too many incorrect attempts. Wait five minutes, then try again.")
            }
            throw RooBinError.validation(message: "The unlock code is incorrect or unavailable.")
        }
        _ = try await perform(path: "rest/v1/rpc/execute_protected_action", method: "POST", body: try encoder.encode(ExecuteBody(grantToken: token, targetEntityID: membershipID)), auth: auth)
    }

    func loadDashboard(
        team: TeamOption,
        selection: SeasonSelection,
        auth: AuthSession
    ) async throws -> HomeDashboardModel {
        let teamID = team.id.uuidString
        struct DashboardTeamRow: Decodable {
            let logoURL: URL?
            enum CodingKeys: String, CodingKey { case logoURL = "logo_url" }
        }
        let teamData = try await perform(
            path: "rest/v1/teams?select=logo_url&id=eq.\(teamID)&limit=1",
            method: "GET",
            body: nil,
            auth: auth
        )
        let membershipData = try await perform(
            path: "rest/v1/team_memberships?select=players(id,name,display_name)&team_id=eq.\(teamID)&status=eq.active",
            method: "GET",
            body: nil,
            auth: auth
        )
        let seasonData = try await perform(
            path: "rest/v1/seasons?select=id,name&team_id=eq.\(teamID)&order=name.asc",
            method: "GET",
            body: nil,
            auth: auth
        )
        let matchData = try await perform(
            path: "rest/v1/matches?select=id,date,season_id,opponent,venue,submitted,edit_version&team_id=eq.\(teamID)",
            method: "GET",
            body: nil,
            auth: auth
        )

        let memberships = try decoder.decode([DashboardMembershipRow].self, from: membershipData)
        let teamLogoURL = try decoder.decode([DashboardTeamRow].self, from: teamData).first?.logoURL
        let seasons = try decoder.decode([SeasonRow].self, from: seasonData).map {
            SeasonOption(id: $0.id, name: $0.name)
        }
        let matches = try decoder.decode([MatchRow].self, from: matchData)
        let matchIDs = Set(matches.map(\.id))

        let fineData = try await perform(
            path: "rest/v1/fines?select=id,match_id,player_id,player_name,fine_name,cost,paid",
            method: "GET",
            body: nil,
            auth: auth
        )
        let subData = try await perform(
            path: "rest/v1/subs?select=id,match_id,player_id,player_name,amount,paid",
            method: "GET",
            body: nil,
            auth: auth
        )
        let allFines = try decoder.decode([FineRow].self, from: fineData)
            .filter { matchIDs.contains($0.matchID) }
        let allSubs = try decoder.decode([SubRow].self, from: subData)
            .filter { matchIDs.contains($0.matchID) }

        let validatedSelection = selection.validated(against: seasons)
        let filteredMatches: [MatchRow]
        switch validatedSelection {
        case .all:
            filteredMatches = matches
        case let .season(seasonID):
            filteredMatches = matches.filter { $0.seasonID == seasonID }
        }
        let filteredMatchIDs = Set(filteredMatches.map(\.id))
        let fines = allFines.filter { filteredMatchIDs.contains($0.matchID) }
        let subs = allSubs.filter { filteredMatchIDs.contains($0.matchID) }

        let total = fines.reduce(Decimal.zero) { $0 + $1.cost }
            + subs.reduce(Decimal.zero) { $0 + $1.amount }
        let paid = fines.filter(\.paid).reduce(Decimal.zero) { $0 + $1.cost }
            + subs.filter(\.paid).reduce(Decimal.zero) { $0 + $1.amount }

        let balances = memberships.compactMap { membership -> DashboardPlayerBalance? in
            let player = membership.players
            let playerFines = fines.filter { $0.playerID == player.id }
            let playerSubs = subs.filter { $0.playerID == player.id }
            let playerTotal = playerFines.reduce(Decimal.zero) { $0 + $1.cost }
                + playerSubs.reduce(Decimal.zero) { $0 + $1.amount }
            guard playerTotal > 0 else { return nil }
            let playerPaid = playerFines.filter(\.paid).reduce(Decimal.zero) { $0 + $1.cost }
                + playerSubs.filter(\.paid).reduce(Decimal.zero) { $0 + $1.amount }
            return DashboardPlayerBalance(
                id: player.id,
                name: player.displayName ?? player.name,
                total: playerTotal,
                paid: playerPaid,
                outstanding: playerTotal - playerPaid
            )
        }
        .sorted {
            if $0.outstanding == $1.outstanding {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.outstanding > $1.outstanding
        }

        return HomeDashboardModel(
            teamName: team.name,
            teamLogoURL: teamLogoURL,
            seasons: seasons,
            selectedSeason: validatedSelection,
            total: total,
            paid: paid,
            outstanding: total - paid,
            matchCount: filteredMatches.count,
            fineCount: fines.count,
            subCount: subs.count,
            playerBalances: balances
        )
    }

    func loadMatchWorkspace(team: TeamOption, auth: AuthSession) async throws -> MatchWorkspace {
        let teamID = team.id.uuidString
        let membershipData = try await perform(
            path: "rest/v1/team_memberships?select=players(id,name,display_name)&team_id=eq.\(teamID)&status=eq.active",
            method: "GET", body: nil, auth: auth
        )
        let seasonData = try await perform(
            path: "rest/v1/seasons?select=id,name&team_id=eq.\(teamID)&order=name.asc",
            method: "GET", body: nil, auth: auth
        )
        let matchData = try await perform(
            path: "rest/v1/matches?select=id,date,season_id,opponent,venue,submitted,edit_version&team_id=eq.\(teamID)&order=date.desc",
            method: "GET", body: nil, auth: auth
        )
        let matchPlayerData = try await perform(
            path: "rest/v1/match_players?select=match_id,player_id,is_driver",
            method: "GET", body: nil, auth: auth
        )
        let fineData = try await perform(
            path: "rest/v1/fines?select=id,match_id,player_id,player_name,fine_name,cost,paid",
            method: "GET", body: nil, auth: auth
        )
        let subData = try await perform(
            path: "rest/v1/subs?select=id,match_id,player_id,player_name,amount,paid",
            method: "GET", body: nil, auth: auth
        )
        let fineTypeData = try await perform(
            path: "rest/v1/fine_types?select=id,name,cost&team_id=eq.\(teamID)&order=cost.asc,name.asc",
            method: "GET", body: nil, auth: auth
        )

        let players = try decoder.decode([DashboardMembershipRow].self, from: membershipData)
            .map { MatchPlayerOption(id: $0.players.id, name: $0.players.displayName ?? $0.players.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let seasons = try decoder.decode([SeasonRow].self, from: seasonData)
        let seasonNames = Dictionary(uniqueKeysWithValues: seasons.map { ($0.id, $0.name) })
        let matches = try decoder.decode([MatchRow].self, from: matchData)
        let matchPlayers = try decoder.decode([MatchPlayerRow].self, from: matchPlayerData)
        let fines = try decoder.decode([FineRow].self, from: fineData)
        let subs = try decoder.decode([SubRow].self, from: subData)
        let fineTypes = try decoder.decode([FineTypeOption].self, from: fineTypeData)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let matchContext = Dictionary(uniqueKeysWithValues: matches.compactMap { match -> (UUID, (Date, UUID?))? in
            guard let date = formatter.date(from: match.date) else { return nil }
            return (match.id, (date, match.seasonID))
        })

        let summaries = matches.compactMap { match -> MatchSummary? in
            guard let date = formatter.date(from: match.date) else { return nil }
            let matchFines = fines.filter { $0.matchID == match.id }
            let matchSubs = subs.filter { $0.matchID == match.id }
            let total = matchFines.reduce(Decimal.zero) { $0 + $1.cost }
                + matchSubs.reduce(Decimal.zero) { $0 + $1.amount }
            return MatchSummary(
                id: match.id,
                date: date,
                opponent: match.opponent ?? "Opponent not set",
                venue: match.venue,
                seasonName: match.seasonID.flatMap { seasonNames[$0] },
                seasonID: match.seasonID,
                submitted: match.submitted,
                editVersion: match.editVersion,
                playerCount: matchPlayers.filter { $0.matchID == match.id }.count,
                fineCount: matchFines.count,
                total: total
            )
        }

        return MatchWorkspace(
            seasons: seasons.map { SeasonOption(id: $0.id, name: $0.name) },
            players: players,
            matches: summaries,
            fineTypes: fineTypes,
            activity: Dictionary(uniqueKeysWithValues: matches.map { match in
                (match.id, MatchActivity(
                    playerIDs: matchPlayers.filter { $0.matchID == match.id }.map(\.playerID),
                    driverIDs: matchPlayers.filter { $0.matchID == match.id && $0.isDriver }.map(\.playerID),
                    fines: fines.filter { $0.matchID == match.id }.map {
                        MatchFineEntry(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, fineName: $0.fineName, cost: $0.cost, paid: $0.paid)
                    },
                    subs: subs.filter { $0.matchID == match.id }.map {
                        MatchSubEntry(id: $0.id, playerID: $0.playerID, playerName: $0.playerName, amount: $0.amount, paid: $0.paid)
                    }
                ))
            }),
            ledgerEntries: (
                fines.compactMap { fine -> LedgerEntry? in
                    guard let context = matchContext[fine.matchID] else { return nil }
                    return LedgerEntry(
                        id: fine.id,
                        matchID: fine.matchID,
                        playerID: fine.playerID,
                        playerName: fine.playerName,
                        label: fine.fineName,
                        kind: .fine,
                        amount: fine.cost,
                        paid: fine.paid,
                        date: context.0,
                        seasonID: context.1
                    )
                }
                + subs.compactMap { sub -> LedgerEntry? in
                    guard let context = matchContext[sub.matchID] else { return nil }
                    return LedgerEntry(
                        id: sub.id,
                        matchID: sub.matchID,
                        playerID: sub.playerID,
                        playerName: sub.playerName,
                        label: "Match subs",
                        kind: .sub,
                        amount: sub.amount,
                        paid: sub.paid,
                        date: context.0,
                        seasonID: context.1
                    )
                }
            ).sorted {
                if $0.date == $1.date {
                    return $0.playerName.localizedCaseInsensitiveCompare($1.playerName) == .orderedAscending
                }
                return $0.date > $1.date
            }
        )
    }

    func addFine(matchID: UUID, playerID: UUID, fineTypeID: UUID, auth: AuthSession) async throws {
        struct Body: Encodable {
            let operationID = UUID()
            let targetMatchID: UUID
            let targetPlayerID: UUID
            let targetFineTypeID: UUID
            enum CodingKeys: String, CodingKey {
                case operationID = "operation_id"
                case targetMatchID = "target_match_id"
                case targetPlayerID = "target_player_id"
                case targetFineTypeID = "target_fine_type_id"
            }
        }
        let body = try encoder.encode(Body(targetMatchID: matchID, targetPlayerID: playerID, targetFineTypeID: fineTypeID))
        _ = try await perform(path: "rest/v1/rpc/add_match_fine", method: "POST", body: body, auth: auth)
    }

    func updateMatchParticipants(
        matchID: UUID,
        playerIDs: Set<UUID>,
        driverIDs: Set<UUID>,
        auth: AuthSession
    ) async throws {
        struct Participant: Encodable {
            let playerID: UUID
            let isDriver: Bool
            enum CodingKeys: String, CodingKey { case playerID = "playerId"; case isDriver }
        }
        struct Body: Encodable {
            let operationID = UUID()
            let targetMatchID: UUID
            let participants: [Participant]
            enum CodingKeys: String, CodingKey {
                case operationID = "operation_id"
                case targetMatchID = "target_match_id"
                case participants
            }
        }
        let entries = playerIDs.sorted { $0.uuidString < $1.uuidString }.map {
            Participant(playerID: $0, isDriver: driverIDs.contains($0))
        }
        let body = try encoder.encode(Body(targetMatchID: matchID, participants: entries))
        _ = try await perform(path: "rest/v1/rpc/update_match_participants", method: "POST", body: body, auth: auth)
    }

    func createFineType(name: String, cost: Decimal, team: TeamOption, auth: AuthSession) async throws {
        struct Body: Encodable {
            let targetTeamID: UUID
            let fineName: String
            let fineCost: Decimal
            enum CodingKeys: String, CodingKey {
                case targetTeamID = "target_team_id"
                case fineName = "fine_name"
                case fineCost = "fine_cost"
            }
        }
        let body = try encoder.encode(Body(targetTeamID: team.id, fineName: name, fineCost: cost))
        _ = try await perform(
            path: "rest/v1/rpc/create_team_fine_type",
            method: "POST", body: body, auth: auth
        )
    }

    func updateFineType(id: UUID, name: String, cost: Decimal, team: TeamOption, auth: AuthSession) async throws {
        struct Body: Encodable {
            let operationID = UUID(); let targetTeamID: UUID; let targetFineTypeID: UUID; let fineName: String; let fineCost: Decimal
            enum CodingKeys: String, CodingKey { case operationID="operation_id", targetTeamID="target_team_id", targetFineTypeID="target_fine_type_id", fineName="fine_name", fineCost="fine_cost" }
        }
        _ = try await perform(path:"rest/v1/rpc/update_team_fine_type",method:"POST",body:try encoder.encode(Body(targetTeamID:team.id,targetFineTypeID:id,fineName:name,fineCost:cost)),auth:auth)
    }

    func loadManagedSeasons(team: TeamOption, auth: AuthSession) async throws -> [ManagedSeason] {
        struct Row: Decodable { let id:UUID; let name:String; let type:String; let source:String? }
        struct MatchSeason: Decodable { let seasonID:UUID?; enum CodingKeys:String,CodingKey { case seasonID="season_id" } }
        let seasonData = try await perform(path:"rest/v1/seasons?select=id,name,type,source&team_id=eq.\(team.id)&order=name.asc",method:"GET",body:nil,auth:auth)
        let matchData = try await perform(path:"rest/v1/matches?select=season_id&team_id=eq.\(team.id)",method:"GET",body:nil,auth:auth)
        let counts = Dictionary(grouping: try decoder.decode([MatchSeason].self,from:matchData).compactMap(\.seasonID),by:{$0}).mapValues(\.count)
        return try decoder.decode([Row].self,from:seasonData).map { ManagedSeason(id:$0.id,name:$0.name,type:$0.type,source:$0.source,matchCount:counts[$0.id] ?? 0) }
    }

    func saveSeason(id:UUID,name:String,type:String,team:TeamOption,auth:AuthSession) async throws {
        struct Body:Encodable { let operationID=UUID();let targetTeamID:UUID;let targetSeasonID:UUID;let seasonName:String;let seasonType:String
            enum CodingKeys:String,CodingKey { case operationID="operation_id",targetTeamID="target_team_id",targetSeasonID="target_season_id",seasonName="season_name",seasonType="season_type" } }
        _ = try await perform(path:"rest/v1/rpc/save_team_season",method:"POST",body:try encoder.encode(Body(targetTeamID:team.id,targetSeasonID:id,seasonName:name,seasonType:type)),auth:auth)
    }

    func deleteManagedEntity(id:UUID,type:String,action:String,unlockCode:String,team:TeamOption,auth:AuthSession) async throws {
        struct V:Encodable { let targetTeamID:UUID;let protectedAction:String;let suppliedUnlockCode:String
            enum CodingKeys:String,CodingKey { case targetTeamID="target_team_id",protectedAction="protected_action",suppliedUnlockCode="supplied_unlock_code" } }
        struct R:Decodable { let authorized:Bool;let grantToken:UUID?;let reason:String? }
        struct E:Encodable { let grantToken:UUID;let targetEntityType:String;let targetEntityID:UUID
            enum CodingKeys:String,CodingKey { case grantToken="grant_token",targetEntityType="target_entity_type",targetEntityID="target_entity_id" } }
        let data=try await perform(path:"rest/v1/rpc/verify_team_unlock_code",method:"POST",body:try encoder.encode(V(targetTeamID:team.id,protectedAction:action,suppliedUnlockCode:unlockCode)),auth:auth)
        let result=try decoder.decode(R.self,from:data)
        guard result.authorized,let token=result.grantToken else { if result.reason=="rate_limited" { throw RooBinError.rateLimited };throw RooBinError.validation(message:"The unlock code is incorrect or unavailable.") }
        _=try await perform(path:"rest/v1/rpc/execute_protected_action",method:"POST",body:try encoder.encode(E(grantToken:token,targetEntityType:type,targetEntityID:id)),auth:auth)
    }

    func updatePaymentStatus(
        entries: [LedgerEntry],
        paid: Bool,
        team: TeamOption,
        auth: AuthSession
    ) async throws {
        struct Body: Encodable {
            struct Item: Encodable {
                let kind: String
                let id: UUID
                let paid: Bool
            }

            let operationID: UUID
            let targetTeamID: UUID
            let items: [Item]

            enum CodingKeys: String, CodingKey {
                case items
                case operationID = "operation_id"
                case targetTeamID = "target_team_id"
            }
        }

        guard !entries.isEmpty else {
            throw RooBinError.validation(message: "Select at least one ledger entry.")
        }
        let body = try encoder.encode(
            Body(
                operationID: UUID(),
                targetTeamID: team.id,
                items: entries.map { .init(kind: $0.kind.rawValue, id: $0.id, paid: paid) }
            )
        )
        _ = try await perform(
            path: "rest/v1/rpc/update_payment_batch",
            method: "POST", body: body, auth: auth
        )
    }

    func reassignFine(
        fineID: UUID,
        playerID: UUID,
        team: TeamOption,
        auth: AuthSession
    ) async throws {
        struct Body: Encodable {
            let operationID = UUID()
            let targetTeamID: UUID
            let targetFineID: UUID
            let targetPlayerID: UUID
            enum CodingKeys: String, CodingKey {
                case operationID = "operation_id"
                case targetTeamID = "target_team_id"
                case targetFineID = "target_fine_id"
                case targetPlayerID = "target_player_id"
            }
        }
        let body = try encoder.encode(
            Body(targetTeamID: team.id, targetFineID: fineID, targetPlayerID: playerID)
        )
        _ = try await perform(
            path: "rest/v1/rpc/reassign_match_fine",
            method: "POST", body: body, auth: auth
        )
    }

    func deleteLedgerEntry(
        _ entry: LedgerEntry,
        unlockCode: String,
        team: TeamOption,
        auth: AuthSession
    ) async throws {
        struct VerifyBody: Encodable {
            let targetTeamID: UUID
            let protectedAction = "delete_fine_entry"
            let suppliedUnlockCode: String
            enum CodingKeys: String, CodingKey {
                case targetTeamID = "target_team_id"
                case protectedAction = "protected_action"
                case suppliedUnlockCode = "supplied_unlock_code"
            }
        }
        struct VerifyResponse: Decodable {
            let authorized: Bool
            let grantToken: UUID?
            let reason: String?
        }
        struct ExecuteBody: Encodable {
            let grantToken: UUID
            let targetEntityType: String
            let targetEntityID: UUID
            enum CodingKeys: String, CodingKey {
                case grantToken = "grant_token"
                case targetEntityType = "target_entity_type"
                case targetEntityID = "target_entity_id"
            }
        }

        let verifyData = try await perform(
            path: "rest/v1/rpc/verify_team_unlock_code",
            method: "POST",
            body: try encoder.encode(
                VerifyBody(targetTeamID: team.id, suppliedUnlockCode: unlockCode)
            ),
            auth: auth
        )
        let verification = try decoder.decode(VerifyResponse.self, from: verifyData)
        guard verification.authorized, let grantToken = verification.grantToken else {
            if verification.reason == "rate_limited" { throw RooBinError.rateLimited }
            throw RooBinError.validation(message: "The unlock code is incorrect or unavailable.")
        }
        _ = try await perform(
            path: "rest/v1/rpc/execute_protected_action",
            method: "POST",
            body: try encoder.encode(
                ExecuteBody(
                    grantToken: grantToken,
                    targetEntityType: entry.kind.rawValue,
                    targetEntityID: entry.id
                )
            ),
            auth: auth
        )
    }

    func submitMatch(_ matchID: UUID, auth: AuthSession) async throws {
        struct Body: Encodable {
            let operationID = UUID()
            let targetMatchID: UUID
            enum CodingKeys: String, CodingKey {
                case operationID = "operation_id"
                case targetMatchID = "target_match_id"
            }
        }
        _ = try await perform(
            path: "rest/v1/rpc/submit_match",
            method: "POST",
            body: try encoder.encode(Body(targetMatchID: matchID)),
            auth: auth
        )
    }

    func updateMatchFixture(_ draft: MatchFixtureDraft, auth: AuthSession) async throws -> Int64 {
        struct Body: Encodable {
            let operationID = UUID()
            let targetMatchID: UUID
            let expectedVersion: Int64
            let fixtureDate: String
            let fixtureOpponent: String
            let fixtureVenue: String
            let fixtureSeasonID: UUID?
            enum CodingKeys: String, CodingKey {
                case operationID = "operation_id"
                case targetMatchID = "target_match_id"
                case expectedVersion = "expected_version"
                case fixtureDate = "fixture_date"
                case fixtureOpponent = "fixture_opponent"
                case fixtureVenue = "fixture_venue"
                case fixtureSeasonID = "fixture_season_id"
            }
        }
        struct Response: Decodable { let editVersion: Int64 }
        let data = try await perform(
            path: "rest/v1/rpc/update_match_fixture",
            method: "POST",
            body: try encoder.encode(
                Body(
                    targetMatchID: draft.matchID,
                    expectedVersion: draft.expectedVersion,
                    fixtureDate: Self.dateFormatter.string(from: draft.date),
                    fixtureOpponent: draft.opponent,
                    fixtureVenue: draft.venue.rawValue,
                    fixtureSeasonID: draft.seasonID
                )
            ),
            auth: auth
        )
        return try decoder.decode(Response.self, from: data).editVersion
    }

    func invitePlayer(
        displayName: String,
        email: String,
        team: TeamOption,
        auth: AuthSession
    ) async throws -> String {
        struct Body: Encodable {
            let action = "invite"
            let teamID: UUID
            let email: String
            let displayName: String
            enum CodingKeys: String, CodingKey {
                case action, email, displayName
                case teamID = "teamId"
            }
        }
        struct Response: Decodable {
            let delivered: Bool
            let message: String
        }
        let body = try encoder.encode(Body(teamID: team.id, email: email, displayName: displayName))
        let data = try await perform(
            path: "functions/v1/team-communications",
            method: "POST", body: body, auth: auth
        )
        return try decoder.decode(Response.self, from: data).message
    }

    func createMatch(_ draft: MatchDraft, team: TeamOption, auth: AuthSession) async throws {
        let settingsData = try await perform(
            path: "rest/v1/teams?select=subs_enabled,drivers_void_subs,sub_amount&id=eq.\(team.id.uuidString)&limit=1",
            method: "GET", body: nil, auth: auth
        )
        guard let settings = try decoder.decode([TeamSettingsRow].self, from: settingsData).first else {
            throw RooBinError.notFound
        }
        let workspace = try await loadMatchWorkspace(team: team, auth: auth)
        let names = Dictionary(uniqueKeysWithValues: workspace.players.map { ($0.id, $0.name) })
        let chargeablePlayers = draft.playerIDs.filter {
            settings.subsEnabled && !(draft.venue == .away && settings.driversVoidSubs && draft.driverIDs.contains($0))
        }
        let aggregate = SaveMatchBody.Aggregate(
            id: draft.id,
            teamID: team.id,
            date: Self.dateFormatter.string(from: draft.date),
            seasonID: draft.seasonID,
            opponent: draft.opponent,
            venue: draft.venue.rawValue,
            players: draft.playerIDs.sorted { $0.uuidString < $1.uuidString }.map {
                .init(playerID: $0, isDriver: draft.driverIDs.contains($0))
            },
            subs: chargeablePlayers.sorted { $0.uuidString < $1.uuidString }.map {
                .init(id: UUID(), playerID: $0, playerName: names[$0] ?? "Unknown", amount: settings.subAmount, paid: false)
            }
        )
        let body = try encoder.encode(SaveMatchBody(operationID: UUID(), aggregate: aggregate))
        _ = try await perform(
            path: "rest/v1/rpc/save_match_aggregate",
            method: "POST", body: body, auth: auth
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func perform(
        path: String,
        method: String,
        body: Data?,
        auth: AuthSession
    ) async throws -> Data {
        if configuration.forceSlowNetwork {
            try await Task.sleep(for: .seconds(3))
        }
        if configuration.forceServiceUnavailable { throw RooBinError.serviceUnavailable }
        if configuration.forceOffline { throw RooBinError.offline }
        guard let url = URL(string: path, relativeTo: configuration.supabaseURL) else {
            throw RooBinError.unexpected
        }
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store, no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue(configuration.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw RooBinError.unexpected
            }
            let backendError = try? decoder.decode(BackendError.self, from: data)
            #if DEBUG
            if !(200..<300).contains(response.statusCode) {
                Self.logger.error(
                    "Request failed status=\(response.statusCode, privacy: .public) code=\(backendError?.code ?? "unknown", privacy: .public) message=\(backendError?.message ?? "unavailable", privacy: .public)"
                )
            }
            #endif
            switch response.statusCode {
            case 200..<300:
                return data
            case 400, 422:
                if backendError?.message?.localizedCaseInsensitiveContains("changed elsewhere") == true {
                    throw RooBinError.conflict
                }
                throw RooBinError.validation(message: "Check the details and try again.")
            case 401:
                throw RooBinError.unauthenticated
            case 403:
                throw RooBinError.forbidden
            case 404:
                throw RooBinError.notFound
            case 409:
                throw RooBinError.conflict
            case 429:
                throw RooBinError.rateLimited
            case 500...599:
                throw RooBinError.serviceUnavailable
            default:
                throw RooBinError.unexpected
            }
        } catch let error as RooBinError {
            throw error
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw RooBinError.offline
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RooBinError.unexpected
        }
    }
}
