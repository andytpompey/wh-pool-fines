import SwiftUI

struct HomeDashboardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: HomeDashboardModel
    var errorMessage: String? = nil
    let selectSeason: (SeasonSelection) -> Void
    let refresh: () async -> Void

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [
            GridItem(.flexible(), spacing: RooBinTheme.Spacing.standard),
            GridItem(.flexible(), spacing: RooBinTheme.Spacing.standard)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: RooBinTheme.Spacing.standard) {
                    header

                    if let errorMessage {
                        RooBinCard {
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(RooBinTheme.Colors.danger)
                                .accessibilityIdentifier("home.error")
                        }
                    }

                    if hasActivity {
                        summaryGrid
                        playerBalances
                    } else {
                        ContentUnavailableView {
                            Label("No team activity yet", systemImage: "chart.bar")
                        } description: {
                            Text("Matches, fines, subs and balances will appear here.")
                        }
                        .frame(maxWidth: .infinity, minHeight: 280)
                        .accessibilityIdentifier("home.empty")
                    }
                }
                .padding(RooBinTheme.Spacing.standard)
            }
            .background(RooBinTheme.Colors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refresh()
            }
        }
    }

    private var hasActivity: Bool {
        model.matchCount > 0 || model.fineCount > 0 || model.subCount > 0
    }

    private var header: some View {
        RooBinCard {
            VStack(alignment: .leading, spacing: RooBinTheme.Spacing.compact) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: RooBinTheme.Spacing.compact) {
                        Text("Season overview")
                            .foregroundStyle(RooBinTheme.Colors.secondaryText)
                        SeasonPicker(
                            seasons: model.seasons,
                            selection: model.effectiveSeason,
                            select: selectSeason
                        )
                    }
                } else {
                    HStack {
                        Text("Season overview")
                            .font(.subheadline)
                            .foregroundStyle(RooBinTheme.Colors.secondaryText)

                        Spacer()

                        SeasonPicker(
                            seasons: model.seasons,
                            selection: model.effectiveSeason,
                            select: selectSeason
                        )
                    }
                }
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: columns, spacing: RooBinTheme.Spacing.standard) {
            DashboardMetricCard(
                title: "Total",
                value: currency(model.total),
                detail: "\(model.fineCount) fines · \(model.subCount) subs",
                colour: RooBinTheme.Colors.primaryText
            )
            DashboardMetricCard(
                title: "Outstanding",
                value: currency(model.outstanding),
                detail: "Unpaid balance",
                colour: RooBinTheme.Colors.danger
            )
            DashboardMetricCard(
                title: "Collected",
                value: currency(model.paid),
                detail: "Paid balance",
                colour: RooBinTheme.Colors.success
            )
            DashboardMetricCard(
                title: "Collection rate",
                value: "\(model.collectionRate)%",
                detail: "\(model.matchCount) matches",
                colour: RooBinTheme.Colors.accent
            )
        }
    }

    private var playerBalances: some View {
        VStack(alignment: .leading, spacing: RooBinTheme.Spacing.compact) {
            Text("Player balances")
                .font(.headline)
                .foregroundStyle(RooBinTheme.Colors.primaryText)
                .accessibilityAddTraits(.isHeader)

            ForEach(model.playerBalances) { player in
                RooBinCard {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: RooBinTheme.Spacing.compact) {
                            playerIdentity(player)
                            outstandingBalance(player)
                        }
                    } else {
                        HStack {
                            playerIdentity(player)
                            Spacer()
                            outstandingBalance(player)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder private func playerIdentity(_ player: DashboardPlayerBalance) -> some View {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.name)
                                .font(.headline)
                                .foregroundStyle(RooBinTheme.Colors.primaryText)
                            Text("\(currency(player.paid)) paid of \(currency(player.total))")
                                .font(.caption)
                                .foregroundStyle(RooBinTheme.Colors.secondaryText)
                        }
    }

    @ViewBuilder private func outstandingBalance(_ player: DashboardPlayerBalance) -> some View {
                        Text(
                            player.outstanding > 0
                                ? "\(currency(player.outstanding)) owed"
                                : "All clear"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(
                            player.outstanding > 0
                                ? RooBinTheme.Colors.danger
                                : RooBinTheme.Colors.success
                        )
    }

    private func currency(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).doubleValue.formatted(
            .currency(code: "GBP")
        )
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let colour: Color

    var body: some View {
        RooBinCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(colour)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(RooBinTheme.Colors.secondaryText)
                Text(title.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(RooBinTheme.Colors.secondaryText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue("\(value), \(detail)")
        }
    }
}

#Preview("Dashboard") {
    HomeDashboardView(
        model: .preview,
        selectSeason: { _ in },
        refresh: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Empty dashboard") {
    HomeDashboardView(
        model: .empty,
        selectSeason: { _ in },
        refresh: {}
    )
    .preferredColorScheme(.dark)
}

private extension HomeDashboardModel {
    static var preview: HomeDashboardModel {
        let seasonID = UUID()
        return HomeDashboardModel(
            teamName: "RooBin Athletic",
            teamLogoURL: nil,
            seasons: [.init(id: seasonID, name: "2026/27")],
            selectedSeason: .season(seasonID),
            total: 42.50,
            paid: 27.00,
            outstanding: 15.50,
            matchCount: 8,
            fineCount: 19,
            subCount: 24,
            playerBalances: [
                .init(
                    id: UUID(),
                    name: "Alex",
                    total: 12.50,
                    paid: 5.00,
                    outstanding: 7.50
                ),
                .init(
                    id: UUID(),
                    name: "Morgan",
                    total: 8.00,
                    paid: 8.00,
                    outstanding: 0
                )
            ]
        )
    }
}
