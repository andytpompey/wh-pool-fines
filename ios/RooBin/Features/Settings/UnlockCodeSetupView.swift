import SwiftUI

struct UnlockCodeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var confirmation = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    let setCode: (String) async throws -> Void

    var body: some View {
        Form {
            Section {
                SecureField("4–12 digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.newPassword)
                    .privacySensitive()
                SecureField("Confirm code", text: $confirmation)
                    .keyboardType(.numberPad)
                    .textContentType(.newPassword)
                    .privacySensitive()
            } header: {
                Text("Team unlock code")
            } footer: {
                Text("Captains and vice-captains use this shared code for protected actions. RooBin never stores it on this device or returns it from the server.")
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(RooBinTheme.Colors.danger)
            }

            Button("Set unlock code") { save() }
                .disabled(!isValid || isSaving)
        }
        .navigationTitle("Unlock security")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isValid: Bool {
        (4...12).contains(code.count)
            && code == confirmation
            && code.allSatisfy(\.isNumber)
    }

    private func save() {
        guard isValid, !isSaving else { return }
        let suppliedCode = code
        isSaving = true
        errorMessage = nil
        Task {
            defer {
                code = ""
                confirmation = ""
                isSaving = false
            }
            do {
                try await setCode(suppliedCode)
                dismiss()
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }
}
