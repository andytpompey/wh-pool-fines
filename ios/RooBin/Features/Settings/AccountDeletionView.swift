import SwiftUI

struct AccountDeletionView: View {
    @State private var preflight: AccountDeletionPreflight?
    @State private var verificationCode = ""
    @State private var confirmationText = ""
    @State private var codeSent = false
    @State private var isLoading = true
    @State private var isSendingCode = false
    @State private var isConfirming = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    let loadPreflight: () async throws -> AccountDeletionPreflight
    let requestCode: (String) async throws -> Void
    let deleteAccount: (String, String) async throws -> Void

    var body: some View {
        List {
            Section {
                Label("Account deletion is permanent", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(RooBinTheme.Colors.danger)
            } footer: {
                Text("Your account is deleted immediately after verification. This cannot be undone.")
            }

            if isLoading {
                Section { ProgressView("Checking account impact…") }
            } else if let preflight {
                impactSections(preflight)
                verificationSection(preflight)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(RooBinTheme.Colors.danger)
                }
            }

            if let preflight {
                Section {
                    Button("Delete my account", role: .destructive) {
                        isConfirming = true
                    }
                    .disabled(!canDelete(preflight) || isDeleting)
                    .accessibilityIdentifier("account.delete")
                } footer: {
                    if !preflight.captaincyBlockers.isEmpty {
                        Text("Transfer captaincy for every team listed above before deletion.")
                    }
                }
            }
        }
        .navigationTitle("Delete account")
        .task { await refreshPreflight() }
        .refreshable { await refreshPreflight() }
        .confirmationDialog(
            "Permanently delete your RooBin account?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Delete account now", role: .destructive) { performDeletion() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your identity and profile will be removed immediately. Historical team entries use a random sport-themed alias.")
        }
        .overlay {
            if isDeleting {
                ProgressView("Deleting account…")
                    .controlSize(.large)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Deleting account")
            }
        }
    }

    @ViewBuilder
    private func impactSections(_ preflight: AccountDeletionPreflight) -> some View {
        Section("What is deleted") {
            Label("Sign-in identity and all active sessions", systemImage: "person.crop.circle.badge.xmark")
            Label("Profile, contact details and team memberships", systemImage: "person.text.rectangle")
            Label("Pending invitations addressed to you", systemImage: "envelope.badge")
            Label("Credentials and cached session on this iPhone", systemImage: "iphone.slash")
        }

        Section("Historical team records") {
            Text("All your personal information will be removed.")
            LabeledContent("Fine entries", value: preflight.historicalFineCount.formatted())
            LabeledContent("Subscription entries", value: preflight.historicalSubCount.formatted())
        }

        if !preflight.teamsDeletedWithAccount.isEmpty {
            Section {
                ForEach(preflight.teamsDeletedWithAccount) { team in
                    Label(team.teamName, systemImage: "person.3.fill")
                }
            } header: {
                Text("Teams closed with your account")
            } footer: {
                Text("You are the only active member of these teams, so their complete history and logo will also be deleted.")
            }
        }

        if !preflight.captaincyBlockers.isEmpty {
            Section("Captaincy transfer required") {
                ForEach(preflight.captaincyBlockers) { blocker in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(blocker.teamName, systemImage: "person.badge.key")
                        Text("\(blocker.otherActiveMembers) other active member\(blocker.otherActiveMembers == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(RooBinTheme.Colors.secondaryText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func verificationSection(_ preflight: AccountDeletionPreflight) -> some View {
        Section("Verify it’s you") {
            Text("We’ll send a fresh eight-digit code to \(preflight.email).")
                .privacySensitive()
            Button(codeSent ? "Send another code" : "Send verification code") {
                sendCode(to: preflight.email)
            }
            .disabled(isSendingCode || !preflight.captaincyBlockers.isEmpty)

            if codeSent {
                TextField("Eight-digit code", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .privacySensitive()
                    .onChange(of: verificationCode) { _, value in
                        verificationCode = String(value.filter(\.isNumber).prefix(8))
                    }
                TextField("Type DELETE to confirm", text: $confirmationText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
        }
    }

    private func canDelete(_ preflight: AccountDeletionPreflight) -> Bool {
        preflight.captaincyBlockers.isEmpty
            && codeSent
            && verificationCode.count == 8
            && confirmationText == "DELETE"
    }

    private func refreshPreflight() async {
        isLoading = true
        errorMessage = nil
        do { preflight = try await loadPreflight() }
        catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
        } catch { errorMessage = RooBinError.unexpected.localizedDescription }
        isLoading = false
    }

    private func sendCode(to email: String) {
        guard !isSendingCode else { return }
        isSendingCode = true
        errorMessage = nil
        Task {
            defer { isSendingCode = false }
            do {
                try await requestCode(email)
                codeSent = true
                verificationCode = ""
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch { errorMessage = RooBinError.unexpected.localizedDescription }
        }
    }

    private func performDeletion() {
        guard let preflight, canDelete(preflight), !isDeleting else { return }
        isDeleting = true
        errorMessage = nil
        Task {
            defer { isDeleting = false }
            do { try await deleteAccount(preflight.email, verificationCode) }
            catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
                await refreshPreflight()
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
                await refreshPreflight()
            }
        }
    }
}
