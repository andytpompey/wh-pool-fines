import SwiftUI

struct TeamOnboardingView: View {
    enum Destination: Hashable {
        case create
        case join
    }

    @State private var path: [Destination] = []

    let createTeam: (String) async throws -> TeamOption
    let joinTeam: (String) async throws -> TeamOption
    let selectTeam: (TeamOption) -> Void

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                RooBinTheme.Colors.background
                    .ignoresSafeArea()

                ContentUnavailableView {
                    Label("Join your team", systemImage: "person.3")
                } description: {
                    Text("Create a new team or enter a code from your captain.")
                } actions: {
                    Button("Create a team") {
                        path.append(.create)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("teamOnboarding.create")

                    Button("Join with a code") {
                        path.append(.join)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("teamOnboarding.join")
                }
            }
            .navigationTitle("Teams")
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .create:
                    CreateTeamView { name in
                        let team = try await createTeam(name)
                        selectTeam(team)
                    }
                case .join:
                    JoinTeamView { code in
                        let team = try await joinTeam(code)
                        selectTeam(team)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
