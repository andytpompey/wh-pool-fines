import SwiftUI

struct InvitePlayerView: View {
    @State private var displayName = ""
    @State private var email = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    let invitePlayer: (String, String) async throws -> String

    var body: some View {
        Form {
            Section {
                TextField("Display name", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .textContentType(.name)
                TextField("Email address", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
            } header: {
                Text("Player")
            } footer: {
                Text("We’ll email a single-use invitation. They become selectable for matches after accepting it.")
            }

            if let errorMessage {
                Section { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(RooBinTheme.Colors.danger) }
            }
            if let successMessage {
                Section { Label(successMessage, systemImage: "checkmark.circle").foregroundStyle(RooBinTheme.Colors.success) }
            }

            Section {
                Button("Send invitation") { send() }
                    .disabled(!canSend || isSending)
            }
        }
        .navigationTitle("Add player")
        .overlay { if isSending { ProgressView().controlSize(.large) } }
    }

    private var canSend: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && email.contains("@") && email.contains(".")
    }

    private func send() {
        isSending = true
        errorMessage = nil
        successMessage = nil
        Task {
            defer { isSending = false }
            do {
                successMessage = try await invitePlayer(
                    displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                    email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                )
                displayName = ""
                email = ""
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }
}
