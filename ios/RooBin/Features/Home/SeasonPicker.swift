import SwiftUI

struct SeasonPicker: View {
    let seasons: [SeasonOption]
    let selection: SeasonSelection
    let select: (SeasonSelection) -> Void

    var body: some View {
        Menu {
            Button {
                select(.all)
            } label: {
                menuLabel("All seasons", selected: selection == .all)
            }

            ForEach(seasons) { season in
                Button {
                    select(.season(season.id))
                } label: {
                    menuLabel(
                        season.name,
                        selected: selection == .season(season.id)
                    )
                }
            }
        } label: {
            Label(selectedName, systemImage: "calendar")
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Dashboard season")
        .accessibilityValue(selectedName)
        .accessibilityIdentifier("home.seasonPicker")
    }

    private var selectedName: String {
        guard case let .season(id) = selection else {
            return "All seasons"
        }
        return seasons.first(where: { $0.id == id })?.name ?? "All seasons"
    }

    @ViewBuilder
    private func menuLabel(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
