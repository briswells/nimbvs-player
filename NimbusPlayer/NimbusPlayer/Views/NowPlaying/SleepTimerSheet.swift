import SwiftUI

// MARK: - SleepTimerSheet

/// A sheet allowing the user to set a sleep timer or cancel the active one.
///
/// Provides preset durations (5, 10, 15, 30, 60 minutes) and an end-of-chapter
/// option. If a timer is active, shows a cancel button with remaining time.
struct SleepTimerSheet: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayerService.self) private var playerService

    /// Preset sleep timer options in minutes.
    private let presets: [(label: String, minutes: Double)] = [
        ("5 minutes", 5),
        ("10 minutes", 10),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("60 minutes", 60)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Active timer status
                if let remaining = playerService.sleepTimerRemaining {
                    activeTimerBanner(remaining: remaining)
                        .padding(.bottom, NimbusTheme.Dimensions.paddingMedium)
                }

                List {
                    // Duration presets
                    Section {
                        ForEach(presets, id: \.minutes) { preset in
                            Button {
                                playerService.setSleepTimer(minutes: preset.minutes)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                                        .frame(width: 24)

                                    Text(preset.label)
                                        .foregroundStyle(NimbusTheme.Colors.textPrimary)

                                    Spacer()
                                }
                            }
                            .listRowBackground(NimbusTheme.Colors.surfaceElevated)
                        }

                        // End of chapter
                        Button {
                            playerService.setSleepTimerEndOfChapter()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "text.line.last.and.arrowtriangle.forward")
                                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
                                    .frame(width: 24)

                                Text("End of chapter")
                                    .foregroundStyle(NimbusTheme.Colors.textPrimary)

                                Spacer()
                            }
                        }
                        .listRowBackground(NimbusTheme.Colors.surfaceElevated)
                    }

                    // Cancel button (only when timer is active)
                    if playerService.sleepTimerRemaining != nil {
                        Section {
                            Button(role: .destructive) {
                                playerService.cancelSleepTimer()
                                dismiss()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Cancel Timer")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            }
                            .listRowBackground(NimbusTheme.Colors.surfaceElevated)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(NimbusTheme.Colors.backgroundDark)
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(NimbusTheme.Colors.accentPink)
                }
            }
        }
    }

    // MARK: - Active Timer Banner

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
        .padding(.top, NimbusTheme.Dimensions.paddingMedium)
    }

    // MARK: - Formatting

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
