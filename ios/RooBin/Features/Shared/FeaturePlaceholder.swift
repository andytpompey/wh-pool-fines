import SwiftUI

struct FeaturePlaceholder: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        NavigationStack {
            ZStack {
                RooBinTheme.Colors.background
                    .ignoresSafeArea()

                ContentUnavailableView {
                    Label(title, systemImage: systemImage)
                        .foregroundStyle(RooBinTheme.Colors.accent)
                } description: {
                    Text(message)
                        .foregroundStyle(RooBinTheme.Colors.secondaryText)
                }
            }
            .navigationTitle(title)
        }
    }
}
