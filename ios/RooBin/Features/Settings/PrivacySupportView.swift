import SwiftUI

struct PrivacySupportView: View {
    private let privacyURL = URL(string: "https://roobin.trovefinds.co.uk/privacy")!
    private let supportURL = URL(string: "https://roobin.trovefinds.co.uk/support")!
    private let termsURL = URL(string: "https://roobin.trovefinds.co.uk/terms")!

    var body: some View {
        List {
            Section("Privacy") {
                LabeledContent(
                    "Tracking",
                    value: "RooBin does not track you across apps or websites"
                )
                LabeledContent(
                    "Authentication",
                    value: "Secure email code"
                )
                LabeledContent(
                    "Team data",
                    value: "Visible only under team membership rules"
                )
            }

            Section("Support") {
                LabeledContent("App", value: "RooBin")
                LabeledContent("Version", value: version)
                Link("Privacy policy", destination: privacyURL)
                Link("Support and account deletion", destination: supportURL)
                Link("Terms of use", destination: termsURL)
            }
        }
        .navigationTitle("Privacy and support")
    }

    private var version: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "—"
        return "\(version) (\(build))"
    }
}
