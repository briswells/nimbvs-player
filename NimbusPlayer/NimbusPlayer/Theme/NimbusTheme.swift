import SwiftUI

enum NimbusTheme {

    // MARK: - Colors

    enum Colors {
        /// Deep navy background: #1a1a2e
        static let backgroundDark = Color(red: 0x1a / 255.0, green: 0x1a / 255.0, blue: 0x2e / 255.0)

        /// Slightly lighter navy: #16213e
        static let backgroundMedium = Color(red: 0x16 / 255.0, green: 0x21 / 255.0, blue: 0x3e / 255.0)

        /// Mid-tone blue: #0f3460
        static let backgroundLight = Color(red: 0x0f / 255.0, green: 0x34 / 255.0, blue: 0x60 / 255.0)

        /// Accent pink: #e94560
        static let accentPink = Color(red: 0xe9 / 255.0, green: 0x45 / 255.0, blue: 0x60 / 255.0)

        /// Accent purple: #533483
        static let accentPurple = Color(red: 0x53 / 255.0, green: 0x34 / 255.0, blue: 0x83 / 255.0)
    }

    // MARK: - Gradients

    enum Gradients {
        /// Primary accent gradient from pink to purple
        static let accent = LinearGradient(
            colors: [Colors.accentPink, Colors.accentPurple],
            startPoint: .leading,
            endPoint: .trailing
        )

        /// Background gradient from dark to medium navy
        static let background = LinearGradient(
            colors: [Colors.backgroundDark, Colors.backgroundMedium],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Deeper background gradient from dark to light
        static let backgroundDeep = LinearGradient(
            colors: [Colors.backgroundDark, Colors.backgroundLight],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Dimensions

    enum Dimensions {
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16

        static let paddingSmall: CGFloat = 8
        static let paddingMedium: CGFloat = 16
        static let paddingLarge: CGFloat = 24

        static let iconSizeSmall: CGFloat = 20
        static let iconSizeMedium: CGFloat = 28
        static let iconSizeLarge: CGFloat = 44

        static let coverArtSmall: CGFloat = 60
        static let coverArtMedium: CGFloat = 120
        static let coverArtLarge: CGFloat = 240
    }
}
