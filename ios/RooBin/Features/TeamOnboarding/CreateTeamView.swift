import SwiftUI

struct CreateTeamView: View {
    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    let create: (String) async throws -> Void

    var body: some View {
        Form {
            Section {
                TextField("Team name", text: $name)
                    .textContentType(.organizationName)
                    .disabled(isSaving)
                    .accessibilityIdentifier("createTeam.name")
            } footer: {
                Text("You’ll become the team captain.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(RooBinTheme.Colors.danger)
                }
            }

            Section {
                Button("Create team") {
                    submit()
                }
                .disabled(normalisedName.isEmpty || isSaving)
                .accessibilityIdentifier("createTeam.submit")
            }
        }
        .navigationTitle("Create team")
        .overlay {
            if isSaving {
                ProgressView()
                    .accessibilityLabel("Creating team")
            }
        }
    }

    private var normalisedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await create(normalisedName)
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }
}
