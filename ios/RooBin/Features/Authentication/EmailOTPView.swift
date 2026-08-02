import SwiftUI

struct EmailOTPView: View {
    static let expectedCodeLength = 8

    enum Stage {
        case request
        case verify
    }

    @State private var stage: Stage = .request
    @State private var email = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    let requestCode: (String) async throws -> Void
    let verifyCode: (String, String) async throws -> Void

    var body: some View {
        ZStack {
            RooBinTheme.Colors.background
                .ignoresSafeArea()

            Form {
                Section {
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(stage == .verify || isWorking)
                        .accessibilityIdentifier("auth.email.address")

                    if stage == .verify {
                        TextField("Eight-digit code", text: $code)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .disabled(isWorking)
                            .accessibilityIdentifier("auth.email.code")
                    }
                } header: {
                    Text(stage == .request ? "Sign in with email" : "Check your email")
                } footer: {
                    Text(
                        stage == .request
                            ? "We’ll send a short-lived sign-in code."
                            : "Enter the code sent to \(email)."
                    )
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(RooBinTheme.Colors.danger)
                            .accessibilityIdentifier("auth.email.error")
                    }
                }

                Section {
                    Button(stage == .request ? "Send code" : "Verify code") {
                        submit()
                    }
                    .disabled(!canSubmit || isWorking)
                    .accessibilityIdentifier("auth.email.submit")

                    if stage == .verify {
                        Button("Use a different email") {
                            stage = .request
                            code = ""
                            errorMessage = nil
                        }
                        .disabled(isWorking)
                    }
                }
            }
            .scrollContentBackground(.hidden)

            if isWorking {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Signing in")
            }
        }
        .navigationTitle("Email")
    }

    private var normalisedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSubmit: Bool {
        switch stage {
        case .request:
            normalisedEmail.contains("@") && normalisedEmail.contains(".")
        case .verify:
            Self.isValidCode(code)
        }
    }

    static func isValidCode(_ code: String) -> Bool {
        code.count == expectedCodeLength && code.allSatisfy(\.isNumber)
    }

    private func submit() {
        errorMessage = nil
        isWorking = true

        Task {
            defer { isWorking = false }
            do {
                switch stage {
                case .request:
                    try await requestCode(normalisedEmail)
                    stage = .verify
                case .verify:
                    try await verifyCode(normalisedEmail, code)
                }
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }
}
