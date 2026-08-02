import SwiftUI

struct TeamPickerView: View {
    let teams: [TeamOption]
    let selectedTeamID: UUID?
    let select: (TeamOption) -> Void

    var body: some View {
        List(teams) { team in
            Button {
                select(team)
            } label: {
                HStack(spacing: RooBinTheme.Spacing.standard) {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(RooBinTheme.Colors.accent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(team.name)
                            .foregroundStyle(RooBinTheme.Colors.primaryText)
                        Text(team.role.displayName)
                            .font(.caption)
                            .foregroundStyle(RooBinTheme.Colors.secondaryText)
                    }

                    Spacer()

                    if team.id == selectedTeamID {
                        Image(systemName: "checkmark")
                            .foregroundStyle(RooBinTheme.Colors.accent)
                            .accessibilityLabel("Current team")
                    }
                }
                .frame(minHeight: RooBinTheme.Control.minimumTargetSize)
            }
            .accessibilityIdentifier("teamPicker.\(team.id)")
        }
        .overlay {
            if teams.isEmpty {
                ContentUnavailableView(
                    "No teams",
                    systemImage: "person.3",
                    description: Text("Create or join a team to continue.")
                )
            }
        }
        .navigationTitle("Switch team")
    }
}
