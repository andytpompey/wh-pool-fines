import SwiftUI

enum RooBinTheme {
    enum Colors {
        static let background = Color(
            red: 9 / 255,
            green: 9 / 255,
            blue: 11 / 255
        )
        static let surface = Color(
            red: 24 / 255,
            green: 24 / 255,
            blue: 27 / 255
        )
        static let elevatedSurface = Color(
            red: 39 / 255,
            green: 39 / 255,
            blue: 42 / 255
        )
        static let border = Color(
            red: 63 / 255,
            green: 63 / 255,
            blue: 70 / 255
        )
        static let accent = Color(
            red: 242 / 255,
            green: 145 / 255,
            blue: 0
        )
        static let primaryText = Color.white
        static let secondaryText = Color(
            red: 161 / 255,
            green: 161 / 255,
            blue: 170 / 255
        )
        static let success = Color(
            red: 16 / 255,
            green: 185 / 255,
            blue: 129 / 255
        )
        static let warning = accent
        static let danger = Color(
            red: 239 / 255,
            green: 68 / 255,
            blue: 68 / 255
        )
    }

    enum Spacing {
        static let compact: CGFloat = 8
        static let standard: CGFloat = 16
        static let spacious: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat = 16
    }

    enum Control {
        static let minimumTargetSize: CGFloat = 44
    }
}
