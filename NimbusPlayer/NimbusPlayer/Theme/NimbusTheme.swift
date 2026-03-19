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

        /// Primary text color
        static let textPrimary = Color.white

        /// Secondary text color: #8b8fa3
        static let textSecondary = Color(red: 0.545, green: 0.561, blue: 0.639)

        /// Tertiary text color: #6b6f84
        static let textTertiary = Color(red: 0.420, green: 0.435, blue: 0.522)

        /// Semi-transparent white overlay for surfaces
        static let surfaceOverlay = Color.white.opacity(0.06)

        /// Elevated surface color: #232344
        static let surfaceElevated = Color(red: 0.137, green: 0.137, blue: 0.267)

        /// Divider color
        static let divider = Color.white.opacity(0.06)
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
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16

        static let paddingSmall: CGFloat = 8
        static let paddingMedium: CGFloat = 16
        static let paddingLarge: CGFloat = 24

        static let iconSizeSmall: CGFloat = 20
        static let iconSizeMedium: CGFloat = 28
        static let iconSizeLarge: CGFloat = 44

        static let coverThumbnailSize: CGFloat = 52
        static let coverGridSize: CGFloat = 110
        static let coverDetailSize: CGFloat = 200
        static let coverArtSmall: CGFloat = 60
        static let coverArtMedium: CGFloat = 120
        static let coverArtLarge: CGFloat = 240

        static let miniPlayerHeight: CGFloat = 64
        static let tabBarHeight: CGFloat = 56
    }
}
