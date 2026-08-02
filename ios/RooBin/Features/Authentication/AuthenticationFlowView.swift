import SwiftUI

struct AuthenticationFlowView: View {
    enum Screen {
        case welcome
        case email
    }

    @State private var screen: Screen = .welcome
    @State private var pendingProvider: String?

    let requestEmailCode: (String) async throws -> Void
    let verifyEmailCode: (String, String) async throws -> Void

    var body: some View {
        NavigationStack {
            switch screen {
            case .welcome:
                WelcomeView(
                    useEmail: { screen = .email },
                    useApple: { pendingProvider = "Apple" },
                    useGoogle: { pendingProvider = "Google" }
                )
            case .email:
                EmailOTPView(
                    requestCode: requestEmailCode,
                    verifyCode: verifyEmailCode
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.backward") {
                            screen = .welcome
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert(
            "\(pendingProvider ?? "Provider") sign-in",
            isPresented: Binding(
                get: { pendingProvider != nil },
                set: { if !$0 { pendingProvider = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Provider configuration is pending. Email remains the universal fallback.")
        }
    }
}
