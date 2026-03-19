import SwiftUI

// MARK: - ProgressBar

/// A horizontal progress bar that fills from left to right.
///
/// Uses `GeometryReader` to calculate the filled portion based on the
/// `progress` value (0 to 1). Optionally applies the accent gradient.
struct ProgressBar: View {

    // MARK: - Properties

    let progress: Double
    var height: CGFloat = 3
    var showGradient: Bool = true

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(NimbusTheme.Colors.surfaceOverlay)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(fillStyle)
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .frame(height: height)
    }

    // MARK: - Private

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var fillStyle: AnyShapeStyle {
        if showGradient {
            AnyShapeStyle(NimbusTheme.Gradients.accent)
        } else {
            AnyShapeStyle(NimbusTheme.Colors.accentPink)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ProgressBar(progress: 0.3)
        ProgressBar(progress: 0.7, height: 6)
        ProgressBar(progress: 0.5, showGradient: false)
    }
    .padding()
    .background(NimbusTheme.Colors.backgroundDark)
}
