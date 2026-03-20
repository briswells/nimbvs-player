import SwiftUI

struct SleepTimerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayerService.self) private var playerService
    @State private var customMinutes: Double = 20

    private let presets: [Double] = [15, 30, 45]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Active timer banner
                if let remaining = playerService.sleepTimerRemaining {
                    activeTimerBanner(remaining: remaining)
                }

                // Custom slider at top
                VStack(spacing: 8) {
                    HStack {
                        Text("\(Int(customMinutes)) min")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(NimbusTheme.Colors.accentPink)
                            .monospacedDigit()
                        Spacer()
                        Button {
                            playerService.setSleepTimer(minutes: customMinutes)
                            dismiss()
                        } label: {
                            Text("Start")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(NimbusTheme.Gradients.accent)
                                .clipShape(Capsule())
                        }
                    }

                    Slider(value: $customMinutes, in: 1...120, step: 1)
                        .tint(NimbusTheme.Colors.accentPink)
                }
                .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)

                // Quick presets as chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { minutes in
                            Button {
                                playerService.setSleepTimer(minutes: minutes)
                                dismiss()
                            } label: {
                                Text("\(Int(minutes))m")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(NimbusTheme.Colors.surfaceElevated)
                                    .clipShape(Capsule())
                            }
                        }

                        Button {
                            playerService.setSleepTimerEndOfChapter()
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "text.line.last.and.arrowtriangle.forward")
                                    .font(.caption)
                                Text("Chapter end")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(NimbusTheme.Colors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(NimbusTheme.Colors.surfaceElevated)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                }

                // Cancel button
                if playerService.sleepTimerRemaining != nil {
                    Button(role: .destructive) {
                        playerService.cancelSleepTimer()
                        dismiss()
                    } label: {
                        Text("Cancel Timer")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding(.top, NimbusTheme.Dimensions.paddingMedium)
            .background(NimbusTheme.Colors.backgroundDark)
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(NimbusTheme.Colors.accentPink)
                }
            }
        }
    }

    @ViewBuilder
    private func activeTimerBanner(remaining: TimeInterval) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.fill")
                .foregroundStyle(NimbusTheme.Colors.accentPink)

            if remaining == -1 {
                Text("Sleep at end of chapter")
                    .font(.subheadline)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
            } else {
                Text("\(formatRemaining(remaining)) remaining")
                    .font(.subheadline)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(NimbusTheme.Dimensions.paddingMedium)
        .background(NimbusTheme.Colors.accentPink.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius))
        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
