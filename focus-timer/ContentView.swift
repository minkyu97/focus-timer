import SwiftUI
import Combine

#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @ObservedObject var clock: FocusTimerClock
    @ObservedObject var store: TimerStore

    @Environment(\.openWindow) private var openWindow

    @AppStorage("focusTimer.accentColorID") private var accentColorID = FocusTimerTheme.tomato.rawValue
    @AppStorage("focusTimer.soundEnabled") private var soundEnabled = true
    @AppStorage("focusTimer.miniWindowOpacity") private var miniWindowOpacity = 0.92
    @AppStorage("focusTimer.miniWindowClickThrough") private var miniWindowClickThrough = false

    @State private var overlayScreen: OverlayScreen?
    @State private var timeText = FocusTimerFormatting.clock(25 * 60)
    @State private var isEditingTimeText = false
    @State private var editingStartedText: String?
    @FocusState private var isTimeFieldFocused: Bool
    private var theme: FocusTimerTheme {
        FocusTimerTheme(rawValue: accentColorID) ?? .tomato
    }

    var body: some View {
        ZStack {
            landingScreen

            if let overlayScreen {
                overlay(for: overlayScreen)
                    .zIndex(1)
            }
        }
        .frame(width: 340, height: 530)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: clock.completionCount) { _, completionCount in
            if completionCount > 0, soundEnabled {
                playCompletionSound()
            }
        }
        .onChange(of: clock.remainingSeconds) { _, remainingSeconds in
            guard !isEditingTimeText else { return }
            timeText = FocusTimerFormatting.clock(remainingSeconds)
        }
        .onAppear {
            timeText = FocusTimerFormatting.clock(clock.remainingSeconds)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: overlayScreen)
    }

    private var landingScreen: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: finishTimeEditing)

            VStack(spacing: 0) {
                HStack {
                    IconCircleButton(
                        systemName: "line.3.horizontal",
                        accessibilityLabel: "Timers",
                        action: {
                            finishTimeEditing()
                            overlayScreen = .timers
                        }
                    )

                    Spacer()

                    Text("focus timer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    IconCircleButton(
                        systemName: "gearshape",
                        accessibilityLabel: "Settings",
                        action: {
                            finishTimeEditing()
                            overlayScreen = .settings
                        }
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                Spacer(minLength: 16)

                TimerDiskView(
                    remainingSeconds: clock.remainingSeconds,
                    selectedSeconds: clock.selectedSeconds,
                    accentColor: theme.color,
                    isRunning: clock.isRunning,
                    onDurationChange: { seconds in
                        guard !isEditingTimeText else {
                            finishTimeEditing()
                            return
                        }

                        clock.setDuration(seconds)
                    }
                )
                .frame(width: 260, height: 260)
                .padding(.top, 10)
                .simultaneousGesture(TapGesture().onEnded(finishTimeEditing))

                HStack(spacing: 0) {
                    Spacer()

                    Group {
                        if isEditingTimeText {
                            TextField("", text: $timeText)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.plain)
                                .focused($isTimeFieldFocused)
                                .onSubmit(finishTimeEditing)
                                .onExitCommand(perform: cancelTimeEditing)
                                .onAppear {
                                    focusTimeField()
                                }
                                .onChange(of: isTimeFieldFocused) { _, isFocused in
                                    guard !isFocused else { return }
                                    finishTimeEditing()
                                }
                        } else {
                            Text(timeText)
                                .onTapGesture {
                                    beginTimeEditing()
                                }
                            }
                    }

                    Spacer()
                }
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(height: 64)
                .padding(.top, 18)

                HStack(spacing: 12) {
                    IconCircleButton(
                        systemName: "minus",
                        accessibilityLabel: "Decrease by five minutes",
                        action: {
                            finishTimeEditing()
                            clock.adjustDuration(by: -5 * 60)
                        }
                    )
                    .disabled(clock.isRunning)
                    .opacity(clock.isRunning ? 0.45 : 1)

                    IconCircleButton(
                        systemName: "arrow.counterclockwise",
                        accessibilityLabel: "Reset timer",
                        action: {
                            finishTimeEditing()
                            clock.reset()
                        }
                    )

                    Button {
                        finishTimeEditing()

                        if clock.isRunning {
                            clock.pause()
                        } else {
                            store.recordUse(durationSeconds: clock.selectedSeconds)
                            clock.start()
                        }
                    } label: {
                        Image(systemName: clock.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(theme.color, in: Circle())
                            .shadow(color: theme.color.opacity(0.28), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(clock.isRunning ? "Pause timer" : "Start timer")

                    IconCircleButton(
                        systemName: "macwindow",
                        accessibilityLabel: "Open mini timer",
                        action: {
                            finishTimeEditing()
                            openWindow(id: MiniTimerWindowScene.id)
                        }
                    )

                    IconCircleButton(
                        systemName: "plus",
                        accessibilityLabel: "Increase by five minutes",
                        action: {
                            finishTimeEditing()
                            clock.adjustDuration(by: 5 * 60)
                        }
                    )
                    .disabled(clock.isRunning)
                    .opacity(clock.isRunning ? 0.45 : 1)
                }
                .padding(.top, 18)
                .simultaneousGesture(TapGesture().onEnded(finishTimeEditing))

                Spacer(minLength: 22)
            }
        }
    }

    @ViewBuilder
    private func overlay(for screen: OverlayScreen) -> some View {
        switch screen {
        case .timers:
            TimerListOverlayView(
                store: store,
                accentColor: theme.color,
                onSelect: { timer in
                    clock.setDuration(timer.durationSeconds)
                    store.recordUse(durationSeconds: timer.durationSeconds)
                    overlayScreen = nil
                },
                onClose: {
                    overlayScreen = nil
                }
            )
            .transition(.move(edge: .leading).combined(with: .opacity))

        case .settings:
            SettingsOverlayView(
                accentColorID: $accentColorID,
                soundEnabled: $soundEnabled,
                miniWindowOpacity: $miniWindowOpacity,
                miniWindowClickThrough: $miniWindowClickThrough,
                store: store,
                onClose: {
                    overlayScreen = nil
                }
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private func playCompletionSound() {
        #if os(macOS)
        NSSound.beep()
        #endif
    }

    private func beginTimeEditing() {
        guard !isEditingTimeText else { return }

        timeText = FocusTimerFormatting.clock(clock.remainingSeconds)
        editingStartedText = timeText
        isEditingTimeText = true
        focusTimeField()
    }

    private func finishTimeEditing() {
        guard isEditingTimeText else { return }

        commitTimeText()
        isEditingTimeText = false
        isTimeFieldFocused = false
    }

    private func cancelTimeEditing() {
        guard isEditingTimeText else { return }

        timeText = editingStartedText ?? FocusTimerFormatting.clock(clock.remainingSeconds)
        editingStartedText = nil
        isEditingTimeText = false
        isTimeFieldFocused = false
    }

    private func focusTimeField() {
        DispatchQueue.main.async {
            guard isEditingTimeText else { return }
            isTimeFieldFocused = true
        }
    }

    private func commitTimeText() {
        guard let originalText = editingStartedText else {
            timeText = FocusTimerFormatting.clock(clock.remainingSeconds)
            return
        }

        defer { editingStartedText = nil }

        guard timeText != originalText else {
            timeText = FocusTimerFormatting.clock(clock.remainingSeconds)
            return
        }

        guard let seconds = FocusTimerFormatting.seconds(fromTimeInput: timeText) else {
            timeText = FocusTimerFormatting.clock(clock.remainingSeconds)
            return
        }

        clock.setDuration(seconds)
        timeText = FocusTimerFormatting.clock(clock.remainingSeconds)
    }
}

private enum OverlayScreen: Equatable {
    case timers
    case settings
}
