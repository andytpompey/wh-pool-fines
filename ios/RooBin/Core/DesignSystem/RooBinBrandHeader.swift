import SwiftUI

struct RooBinBrandHeader: View {
    let teamName: String?
    let teamLogoURL: URL?

    var body: some View {
        HStack(spacing: RooBinTheme.Spacing.compact) {
            if let teamLogoURL {
                AsyncImage(url: teamLogoURL) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFit()
                    case .empty:
                        ProgressView()
                    case .failure:
                        defaultBrand
                    @unknown default:
                        defaultBrand
                    }
                }
                .containerRelativeFrame(.horizontal) { width, _ in
                    width * 0.45
                }
                .frame(maxHeight: 92)
                .clipShape(RoundedRectangle(cornerRadius: RooBinTheme.Radius.control))
                .accessibilityLabel("\(teamName ?? "Team") logo")

            } else {
                defaultBrand
                    .containerRelativeFrame(.horizontal) { width, _ in
                        width * 0.45
                    }
                    .frame(maxHeight: 92, alignment: .leading)
                    .accessibilityLabel("RooBin")
            }

            Spacer(minLength: 0)

            if let teamName {
                Text(teamName)
                    .font(.headline)
                    .foregroundStyle(RooBinTheme.Colors.primaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .padding(.horizontal, RooBinTheme.Spacing.standard)
        .padding(.vertical, RooBinTheme.Spacing.compact)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RooBinTheme.Colors.border.opacity(0.7))
                .frame(height: 1)
        }
    }

    private var defaultBrand: some View {
        Image("RooBinBanner")
            .resizable()
            .scaledToFit()
    }
}

private struct RooBinBrandHeaderModifier: ViewModifier {
    let teamName: String?
    let teamLogoURL: URL?

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            RooBinBrandHeader(teamName: teamName, teamLogoURL: teamLogoURL)
            content
        }
    }
}

extension View {
    func rooBinBrandHeader(teamName: String?, teamLogoURL: URL?) -> some View {
        modifier(RooBinBrandHeaderModifier(teamName: teamName, teamLogoURL: teamLogoURL))
    }
}
