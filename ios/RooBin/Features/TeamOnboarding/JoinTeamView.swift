import SwiftUI

struct JoinTeamView: View {
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    let join: (String) async throws -> Void

    var body: some View {
        Form {
            Section {
                TextField("Join code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .disabled(isJoining)
                    .accessibilityIdentifier("joinTeam.code")
            } footer: {
                Text("Ask your captain for the team’s join code.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(RooBinTheme.Colors.danger)
                }
            }

            Section {
                Button("Join team") {
                    submit()
                }
                .disabled(normalisedCode.isEmpty || isJoining)
                .accessibilityIdentifier("joinTeam.submit")
            }
        }
        .navigationTitle("Join team")
        .overlay {
            if isJoining {
                ProgressView()
                    .accessibilityLabel("Joining team")
            }
        }
    }

    private var normalisedCode: String {
        code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func submit() {
        isJoining = true
        errorMessage = nil
        Task {
            defer { isJoining = false }
            do {
                try await join(normalisedCode)
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }
}
