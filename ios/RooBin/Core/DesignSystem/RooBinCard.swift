import SwiftUI

struct RooBinCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(RooBinTheme.Spacing.standard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RooBinTheme.Colors.surface)
            .clipShape(.rect(cornerRadius: RooBinTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: RooBinTheme.Radius.card)
                    .stroke(RooBinTheme.Colors.border)
            }
    }
}

#Preview {
    RooBinCard {
        Text("RooBin card")
            .foregroundStyle(RooBinTheme.Colors.primaryText)
    }
    .padding()
    .background(RooBinTheme.Colors.background)
}
