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
    @AppStorage("focusTimer.customAccentColorHex") private var customAccentColorHex = ""
    @AppStorage("focusTimer.appearanceModeID") private var appearanceModeID = FocusTimerAppearanceMode.system.rawValue
    @AppStorage("focusTimer.soundEnabled") private var soundEnabled = true
    @AppStorage("focusTimer.miniWindowOpacity") private var miniWindowOpacity = 0.92
    @AppStorage("focusTimer.miniWindowClickThrough") private var miniWindowClickThrough = false

    @State private var overlayScreen: OverlayScreen?
    @State private var timeText = FocusTimerFormatting.clock(25 * 60)
    @State private var isEditingTimeText = false
    @State private var editingStartedText: String?
    @FocusState private var isTimeFieldFocused: Bool

    private var accentColor: Color {
        FocusTimerAccentColor.color(selectionID: accentColorID, customHex: customAccentColorHex)
    }

    var body: some View {
        ZStack {
            landingScreen

            if let overlayScreen {
                overlay(for: overlayScreen)
                    .zIndex(1)
            }
        }
        .frame(width: MainWindowScene.width, height: MainWindowScene.height)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea(edges: .top))
        .ignoresSafeArea(edges: .top)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            #if os(macOS)
            MainWindowConfigurator(appearanceModeID: appearanceModeID)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            #endif
        }
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
                ZStack {
                    Text("focus timer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)

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

                        IconCircleButton(
                            systemName: "gearshape",
                            accessibilityLabel: "Settings",
                            action: {
                                finishTimeEditing()
                                overlayScreen = .settings
                            }
                        )
                    }
                }
                .padding(.leading, 18)
                .padding(.trailing, 18)
                .padding(.top, MainWindowScene.headerTopPadding)

                Spacer(minLength: 8)

                TimerDiskView(
                    remainingSeconds: clock.remainingSeconds,
                    selectedSeconds: clock.selectedSeconds,
                    accentColor: accentColor,
                    isRunning: clock.isRunning,
                    onDurationChange: { seconds in
                        guard !isEditingTimeText else {
                            finishTimeEditing()
                            return
                        }

                        clock.setDuration(seconds)
                    }
                )
                .frame(width: 248, height: 248)
                .padding(.top, 6)
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
                .frame(height: 58)
                .padding(.top, 12)

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
                            .background(accentColor, in: Circle())
                            .shadow(color: accentColor.opacity(0.28), radius: 10, y: 4)
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
                .padding(.top, 14)
                .simultaneousGesture(TapGesture().onEnded(finishTimeEditing))

                Spacer(minLength: 12)
            }
        }
    }

    @ViewBuilder
    private func overlay(for screen: OverlayScreen) -> some View {
        switch screen {
        case .timers:
            TimerListOverlayView(
                store: store,
                accentColor: accentColor,
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
                customAccentColorHex: $customAccentColorHex,
                appearanceModeID: $appearanceModeID,
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

#if os(macOS)
private struct MainWindowConfigurator: NSViewRepresentable {
    let appearanceModeID: String

    func makeNSView(context: Context) -> NSView {
        let view = FocusTimerAppearanceView()
        view.onWindowOrAppearanceChange = { view in
            context.coordinator.update(from: view, appearanceModeID: appearanceModeID)
        }
        context.coordinator.update(from: view, appearanceModeID: appearanceModeID)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let nsView = nsView as? FocusTimerAppearanceView {
            nsView.onWindowOrAppearanceChange = { view in
                context.coordinator.update(from: view, appearanceModeID: appearanceModeID)
            }
        }

        context.coordinator.update(from: nsView, appearanceModeID: appearanceModeID)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        func update(from view: NSView, appearanceModeID: String) {
            guard let window = view.window else {
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.update(from: view, appearanceModeID: appearanceModeID)
                }
                return
            }

            configure(window, appearanceModeID: appearanceModeID)
        }

        private func configure(_ window: NSWindow, appearanceModeID: String) {
            window.isMovableByWindowBackground = false
            FocusTimerWindowAppearance.apply(modeID: appearanceModeID, to: window)
            window.titlebarSeparatorStyle = .none
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.contentView?.wantsLayer = true
            neutralizeTitlebarSafeArea(in: window)
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
        }

        private func neutralizeTitlebarSafeArea(in window: NSWindow) {
            guard let contentView = window.contentView else { return }

            let reservedTopInset = max(0, window.frame.height - window.contentLayoutRect.height)
            contentView.additionalSafeAreaInsets = NSEdgeInsets(
                top: -reservedTopInset,
                left: 0,
                bottom: 0,
                right: 0
            )
            contentView.needsLayout = true
        }
    }
}
#endif
