import SwiftUI

struct SettingsOverlayView: View {
    @Binding var accentColorID: String
    @Binding var soundEnabled: Bool
    @Binding var miniWindowOpacity: Double
    @Binding var miniWindowClickThrough: Bool

    @ObservedObject var store: TimerStore

    let onClose: () -> Void

    private var selectedTheme: FocusTimerTheme {
        FocusTimerTheme(rawValue: accentColorID) ?? .tomato
    }

    var body: some View {
        VStack(spacing: 0) {
            OverlayHeader(title: "Settings", onClose: onClose)

            VStack(spacing: 18) {
                settingsGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Disk Color")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 14) {
                            ForEach(FocusTimerTheme.allCases) { theme in
                                Button {
                                    accentColorID = theme.rawValue
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(theme.color)
                                            .frame(width: 34, height: 34)

                                        if selectedTheme == theme {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(width: 42, height: 42)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(theme.name)
                            }
                        }
                    }
                }

                settingsGroup {
                    Toggle(isOn: $soundEnabled) {
                        Label("Completion Sound", systemImage: "speaker.wave.2")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .toggleStyle(.switch)
                }

                settingsGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Mini Timer Opacity", systemImage: "circle.lefthalf.filled")
                                .font(.system(size: 14, weight: .medium))

                            Spacer()

                            Text("\(Int(miniWindowOpacity * 100))%")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $miniWindowOpacity, in: 0.35...1, step: 0.05)
                            .tint(selectedTheme.color)
                    }
                }

                settingsGroup {
                    Toggle(isOn: $miniWindowClickThrough) {
                        Label("Mini Timer Click-Through", systemImage: "cursorarrow")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .toggleStyle(.switch)
                }

                settingsGroup {
                    Button {
                        store.clearRecentTimers()
                    } label: {
                        HStack {
                            Label("Clear Recent Timers", systemImage: "trash")
                                .font(.system(size: 14, weight: .medium))

                            Spacer()
                        }
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.timers.allSatisfy(\.isPinned))
                    .opacity(store.timers.allSatisfy(\.isPinned) ? 0.45 : 1)
                }
            }
            .padding(18)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}
