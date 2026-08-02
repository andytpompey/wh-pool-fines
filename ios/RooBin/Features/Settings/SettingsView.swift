import SwiftUI

struct SettingsView: View {
    let teams: [TeamOption]
    let selectedTeamID: UUID?
    let selectTeam: (TeamOption) -> Void
    let createTeam: (String) async throws -> TeamOption
    let joinTeam: (String) async throws -> TeamOption
    let displayName: String
    let receiveTeamNotifications: Bool
    let updateProfile: (String, Bool) async throws -> Void
    let fineTypes: [FineTypeOption]
    let canManageTeam: Bool
    let createFineType: (String, Decimal) async throws -> Void
    let updateFineType: (UUID,String,Decimal) async throws -> Void
    let deleteFineType: (UUID,String) async throws -> Void
    let loadSeasons: () async throws -> [ManagedSeason]
    let saveSeason: (UUID,String,String) async throws -> Void
    let deleteSeason: (UUID,String) async throws -> Void
    let loadCommercialPlayingCycles: () async throws -> [CommercialPlayingCycle]
    let beginAppStorePurchase: (UUID) async throws -> AppStorePurchaseContext
    let verifyAppStoreTransaction: (String) async throws -> AppStoreVerificationResponse
    let loadTeamSettings:() async throws->TeamSettingsModel
    let uploadTeamLogo:(Data) async throws->URL
    let updateTeamSettings:(TeamSettingsModel) async throws->Void
    let invitePlayer: (String, String) async throws -> String
    let setTeamUnlockCode: (String) async throws -> Void
    let changeTeamUnlockCode:(String,String) async throws->Void
    let requestUnlockRecoveryCode:(String) async throws->Void
    let recoverTeamUnlockCode:(String,String) async throws->String
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
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink {
                        EditProfileView(
                            displayName: displayName,
                            receiveTeamNotifications: receiveTeamNotifications,
                            save: updateProfile
                        )
                    } label: {
                        Label("Profile", systemImage: "person.text.rectangle")
                    }

                    NavigationLink {
                        PrivacySupportView()
                    } label: {
                        Label("Privacy and support", systemImage: "lock.shield")
                    }
                }

                Section("Teams") {
                    NavigationLink {
                        TeamSubscriptionView(
                            canPurchase: canManageTeam,
                            load: loadCommercialPlayingCycles,
                            beginPurchase: beginAppStorePurchase,
                            verifyTransaction: verifyAppStoreTransaction
                        )
                    } label: {
                        Label("Team subscription", systemImage: "creditcard")
                    }

                    if canManageTeam {
                        NavigationLink {
                            InvitePlayerView(invitePlayer: invitePlayer)
                        } label: {
                            Label("Add player", systemImage: "person.crop.circle.badge.plus")
                        }

                        if let selectedTeam {
                            NavigationLink {
                                RosterManagementView(
                                    actorRole: selectedTeam.role,
                                    unlockCodeResetRequired: selectedTeam.unlockCodeResetRequired,
                                    load: loadRoster,
                                    setRole: setMemberRole,
                                    transferCaptain: transferCaptain,
                                    removeMember: removeMember,
                                    resendInvite: resendInvite,
                                    revokeInvite: revokeInvite
                                )
                            } label: {
                                Label("Team roster", systemImage: "list.bullet.rectangle.portrait")
                            }
                        }
                    }

                    NavigationLink {
                        TeamPickerView(
                            teams: teams,
                            selectedTeamID: selectedTeamID,
                            select: selectTeam
                        )
                    } label: {
                        Label("Switch team", systemImage: "arrow.left.arrow.right.circle")
                    }

                    NavigationLink {
                        TeamOnboardingView(
                            createTeam: createTeam,
                            joinTeam: joinTeam,
                            selectTeam: selectTeam
                        )
                    } label: {
                        Label("Create or join a team", systemImage: "person.2.badge.plus")
                    }

                    NavigationLink {
                        FineTypeManagementView(
                            fineTypes: fineTypes,
                            canManage: canManageTeam,
                            createFineType: createFineType
                            ,updateFineType:updateFineType,deleteFineType:deleteFineType
                        )
                    } label: {
                        Label("Manage fine types", systemImage: "list.bullet.circle")
                    }
                    if canManageTeam { NavigationLink { TeamSettingsView(load:loadTeamSettings,upload:uploadTeamLogo,save:updateTeamSettings) } label:{Label("Team settings",systemImage:"gearshape.2")} }
                    if canManageTeam { NavigationLink { SeasonManagementView(load:loadSeasons,save:saveSeason,delete:deleteSeason) } label:{Label("Manage seasons",systemImage:"calendar.badge.clock") } }

                    if selectedTeam?.role == .captain && selectedTeam?.unlockCodeResetRequired == true {
                        NavigationLink {
                            UnlockCodeSetupView(setCode: setTeamUnlockCode)
                        } label: {
                            Label("Set team unlock code", systemImage: "key.horizontal")
                        }
                    } else if selectedTeam?.role == .captain {
                        NavigationLink {
                            UnlockSecurityView(
                                change: changeTeamUnlockCode,
                                loadEmail: { try await loadAccountDeletionPreflight().email },
                                requestCode: requestUnlockRecoveryCode,
                                recover: recoverTeamUnlockCode
                            )
                        } label:{Label("Unlock security",systemImage:"key.horizontal")}
                    }
                }

                Section {
                    NavigationLink {
                        AccountDeletionView(
                            loadPreflight: loadAccountDeletionPreflight,
                            requestCode: requestAccountDeletionCode,
                            deleteAccount: deleteAccount
                        )
                    } label: {
                        Label("Delete account", systemImage: "trash")
                            .foregroundStyle(RooBinTheme.Colors.danger)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await signOut() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var selectedTeam: TeamOption? {
        teams.first { $0.id == selectedTeamID }
    }
}
