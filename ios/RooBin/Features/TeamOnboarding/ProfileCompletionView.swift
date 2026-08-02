import SwiftUI

struct ProfileCompletionView: View {
    @State private var displayName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    let save: (String) async throws -> Void

    init(displayName: String = "", save: @escaping (String) async throws -> Void) {
        _displayName = State(initialValue: displayName)
        self.save = save
    }

    var body: some View {
        Form {
            Section {
                TextField("Display name", text: $displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .disabled(isSaving)
                    .accessibilityIdentifier("profile.displayName")
            } header: {
                Text("Complete your profile")
            } footer: {
                Text("This is the name your teammates will see.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(RooBinTheme.Colors.danger)
                        .accessibilityIdentifier("profile.error")
                }
            }

            Section {
                Button("Continue") {
                    submit()
                }
                .disabled(normalisedName.isEmpty || isSaving)
                .accessibilityIdentifier("profile.submit")
            }
        }
        .scrollContentBackground(.hidden)
        .background(RooBinTheme.Colors.background)
        .navigationTitle("Your profile")
        .overlay {
            if isSaving {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Saving profile")
            }
        }
    }

    private var normalisedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        errorMessage = nil
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await save(normalisedName)
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }
}
