import SwiftUI

struct SpeedPickerSheet: View {
    let playerService: AudioPlayerService
    @Environment(\.dismiss) private var dismiss
    @State private var speed: Double

    init(playerService: AudioPlayerService) {
        self.playerService = playerService
        _speed = State(initialValue: playerService.playbackSpeed)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Playback Speed")
                    .font(.headline)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                Spacer()
                Button("Done") {
                    playerService.setPlaybackSpeed(speed)
                    dismiss()
                }
                .foregroundStyle(NimbusTheme.Colors.accentPink)
            }

            Text(String(format: "%.2fx", speed))
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(NimbusTheme.Colors.accentPink)
                .monospacedDigit()

            Slider(value: $speed, in: 0.5...3.0, step: 0.05) {
                Text("Speed")
            } minimumValueLabel: {
                Text("0.5x").font(.caption2).foregroundStyle(NimbusTheme.Colors.textTertiary)
            } maximumValueLabel: {
                Text("3.0x").font(.caption2).foregroundStyle(NimbusTheme.Colors.textTertiary)
            }
            .tint(NimbusTheme.Colors.accentPink)
            .onChange(of: speed) { _, newValue in
                playerService.setPlaybackSpeed(newValue)
            }
        }
        .padding(NimbusTheme.Dimensions.paddingLarge)
        .background(NimbusTheme.Colors.backgroundDark)
    }
}
