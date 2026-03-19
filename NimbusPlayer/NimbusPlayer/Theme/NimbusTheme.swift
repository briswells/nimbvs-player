import SwiftUI
import UIKit

enum NimbusTheme {

    // MARK: - Colors

    enum Colors {
        /// Primary background — custom navy in dark, system background in light
        static let backgroundDark = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x1a / 255.0, green: 0x1a / 255.0, blue: 0x2e / 255.0, alpha: 1)
                : .systemBackground
        })

        /// Secondary background — slightly lighter navy in dark, system grouped in light
        static let backgroundMedium = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x16 / 255.0, green: 0x21 / 255.0, blue: 0x3e / 255.0, alpha: 1)
                : .secondarySystemBackground
        })

        /// Tertiary background — mid-tone blue in dark, tertiary system in light
        static let backgroundLight = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x0f / 255.0, green: 0x34 / 255.0, blue: 0x60 / 255.0, alpha: 1)
                : .tertiarySystemBackground
        })

        /// Grouped list/form background
        static let backgroundGrouped = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x1a / 255.0, green: 0x1a / 255.0, blue: 0x2e / 255.0, alpha: 1)
                : .systemGroupedBackground
        })

        /// Grouped list/form row background
        static let backgroundGroupedRow = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x23 / 255.0, green: 0x23 / 255.0, blue: 0x44 / 255.0, alpha: 1)
                : .secondarySystemGroupedBackground
        })

        /// Accent pink: #e94560
        static let accentPink = Color(red: 0xe9 / 255.0, green: 0x45 / 255.0, blue: 0x60 / 255.0)

        /// Accent purple: #533483
        static let accentPurple = Color(red: 0x53 / 255.0, green: 0x34 / 255.0, blue: 0x83 / 255.0)

        /// Primary text color
        static let textPrimary = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : .label
        })

        /// Secondary text color
        static let textSecondary = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.545, green: 0.561, blue: 0.639, alpha: 1)
                : .secondaryLabel
        })

        /// Tertiary text color
        static let textTertiary = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.420, green: 0.435, blue: 0.522, alpha: 1)
                : .tertiaryLabel
        })

        /// Semi-transparent overlay for surfaces
        static let surfaceOverlay = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.06)
                : UIColor.black.withAlphaComponent(0.04)
        })

        /// Elevated surface color
        static let surfaceElevated = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.137, green: 0.137, blue: 0.267, alpha: 1)
                : .secondarySystemBackground
        })

        /// Divider color
        static let divider = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.06)
                : .separator
        })
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
