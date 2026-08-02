import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var receiveTeamNotifications: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    let save: (String, Bool) async throws -> Void

    init(
        displayName: String,
        receiveTeamNotifications: Bool,
        save: @escaping (String, Bool) async throws -> Void
    ) {
        _displayName = State(initialValue: displayName)
        _receiveTeamNotifications = State(initialValue: receiveTeamNotifications)
        self.save = save
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
            }
            Section {
                Toggle("Receive team notifications", isOn: $receiveTeamNotifications)
            } footer: {
                Text("This controls team email notifications. Essential security and account messages are unaffected.")
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(RooBinTheme.Colors.danger)
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { performSave() }
                    .disabled(normalisedName.isEmpty || isSaving)
            }
        }
    }

    private var normalisedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func performSave() {
        guard !normalisedName.isEmpty, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await save(normalisedName, receiveTeamNotifications)
                dismiss()
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }
}
