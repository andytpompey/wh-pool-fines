import SwiftUI

struct RosterManagementView: View {
    @State private var workspace: RosterWorkspace?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var removalTarget: RosterMember?
    @State private var captainTransferTarget: RosterMember?
    @State private var unlockCode = ""
    @State private var showUnlockSetupAlert = false
    @State private var removalError: String?

    let actorRole: TeamMembershipDTO.Role
    let unlockCodeResetRequired: Bool
    let load: () async throws -> RosterWorkspace
    let setRole: (UUID, TeamMembershipDTO.Role) async throws -> Void
    let transferCaptain: (UUID, UUID) async throws -> Void
    let removeMember: (UUID, String) async throws -> Void
    let resendInvite: (UUID) async throws -> String
    let revokeInvite: (UUID) async throws -> Void

    var body: some View {
        List {
            Section("Active members") {
                if let workspace {
                    ForEach(workspace.members) { member in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(member.name)
                                Text(member.email).font(.caption).foregroundStyle(RooBinTheme.Colors.secondaryText)
                            }
                            Spacer()
                            Text(member.role.displayName).font(.caption.bold())
                            if canManage(member) { memberMenu(member) }
                        }
                    }
                } else { ProgressView() }
            }

            if let invites = workspace?.invites, !invites.isEmpty {
                Section("Pending invitations") {
                    ForEach(invites) { invite in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(invite.email)
                            if let expiresAt = invite.expiresAt {
                                Text("Expires \(expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(RooBinTheme.Colors.secondaryText)
                            }
                            HStack {
                                Button("Resend") { perform { _ = try await resendInvite(invite.id) } }
                                Button("Revoke", role: .destructive) { perform { try await revokeInvite(invite.id) } }
                            }.buttonStyle(.bordered)
                        }
                    }
                }
            }

            if let errorMessage {
                Section { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(RooBinTheme.Colors.danger) }
            }
        }
        .navigationTitle("Team roster")
        .refreshable { await refresh() }
        .task { await refresh() }
        .alert("Team unlock code required", isPresented: $showUnlockSetupAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Set a team unlock code in Settings before removing a member.")
        }
        .sheet(item: $removalTarget) { member in
            NavigationStack {
                Form {
                    Section("Impact") {
                        Text("Removing \(member.name) immediately removes their access to this team. Historic match, fine and payment labels remain for team records.")
                    }
                    Section {
                        SecureField("Team unlock code", text: $unlockCode).keyboardType(.numberPad).privacySensitive()
                        Button("Remove member", role: .destructive) {
                            performRemoval(member)
                        }.disabled(unlockCode.count < 4 || isWorking)
                    }
                    if let removalError {
                        Section {
                            Label(removalError, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(RooBinTheme.Colors.danger)
                        }
                    }
                }
                .navigationTitle("Remove member")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { removalTarget = nil; unlockCode = ""; removalError = nil } } }
            }
        }
        .confirmationDialog(
            "Transfer captaincy?",
            isPresented: Binding(
                get: { captainTransferTarget != nil },
                set: { if !$0 { captainTransferTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: captainTransferTarget
        ) { member in
            Button("Transfer to \(member.name)", role: .destructive) {
                guard let outgoing = workspace?.members.first(where: { $0.role == .captain }) else { return }
                captainTransferTarget = nil
                perform { try await transferCaptain(member.id, outgoing.id) }
            }
            Button("Cancel", role: .cancel) { captainTransferTarget = nil }
        } message: { member in
            Text("You will become a vice-captain and \(member.name) will immediately become the team captain.")
        }
    }

    @ViewBuilder private func memberMenu(_ member: RosterMember) -> some View {
        Menu {
            if actorRole == .captain && member.role != .captain {
                Button(member.role == .viceCaptain ? "Make member" : "Make vice-captain") {
                    perform { try await setRole(member.id, member.role == .viceCaptain ? .member : .viceCaptain) }
                }
                Button("Transfer captaincy") {
                    captainTransferTarget = member
                }
            }
            if member.role != .captain {
                Button("Remove from team", role: .destructive) {
                    if unlockCodeResetRequired {
                        showUnlockSetupAlert = true
                    } else {
                        removalTarget = member
                    }
                }
            }
        } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
    }

    private func canManage(_ member: RosterMember) -> Bool {
        (actorRole == .captain || actorRole == .viceCaptain) && member.role != .captain
    }

    private func perform(_ operation: @escaping () async throws -> Void) {
        guard !isWorking else { return }
        isWorking = true; errorMessage = nil
        Task {
            defer { isWorking = false }
            do { try await operation(); await refresh() }
            catch let error as LocalizedError { errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription }
            catch { errorMessage = RooBinError.unexpected.localizedDescription }
        }
    }

    private func performRemoval(_ member: RosterMember) {
        guard !isWorking else { return }
        isWorking = true
        removalError = nil
        Task {
            defer { isWorking = false }
            do {
                try await removeMember(member.id, unlockCode)
                removalTarget = nil
                unlockCode = ""
                await refresh()
            } catch let caught as LocalizedError {
                removalError = caught.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                removalError = RooBinError.unexpected.localizedDescription
            }
        }
    }

    private func refresh() async {
        do { workspace = try await load(); errorMessage = nil }
        catch let error as LocalizedError { errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription }
        catch { errorMessage = RooBinError.unexpected.localizedDescription }
    }
}
