import SwiftUI
import Combine

#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @ObservedObject var clock: FocusTimerClock
    @ObservedObject var store: TimerStore
    @ObservedObject var windowCommandCenter: FocusTimerWindowCommandCenter
    @ObservedObject var updater: FocusTimerUpdater
    @StateObject private var completionSoundPlayer = FocusTimerCompletionSoundPlayer.shared

    @Environment(\.openWindow) private var openWindow

    @AppStorage("focusTimer.accentColorID") private var accentColorID = FocusTimerTheme.tomato.rawValue
    @AppStorage("focusTimer.customAccentColorHex") private var customAccentColorHex = ""
    @AppStorage("focusTimer.appearanceModeID") private var appearanceModeID = FocusTimerAppearanceMode.system.rawValue
    @AppStorage("focusTimer.soundEnabled") private var soundEnabled = true
    @AppStorage("focusTimer.completionSoundID") private var completionSoundID = FocusTimerCompletionSound.systemAlertID
    @AppStorage("focusTimer.customCompletionSoundName") private var customCompletionSoundName = ""
    @AppStorage("focusTimer.completionNotificationEnabled") private var completionNotificationEnabled = true
    @AppStorage("focusTimer.menuBarIconEnabled") private var menuBarIconEnabled = true
    @AppStorage("focusTimer.menuBarIconStyleID") private var menuBarIconStyleID = FocusTimerMenuBarIconStyle.normal.rawValue
    @AppStorage("focusTimer.floatingTimerOpacity") private var floatingTimerOpacity = 0.92
    @AppStorage("focusTimer.floatingTimerClickThrough") private var floatingTimerClickThrough = false

    @State private var activeTimerOverlay: TimerOverlay?
    @State private var timeText = FocusTimerFormatting.clock(25 * 60)
    @State private var isEditingTimeText = false
    @State private var editingStartedText: String?
    @State private var handledMainWindowRequestID: UUID?
    @FocusState private var isTimeFieldFocused: Bool

    private var accentColor: Color {
        FocusTimerAccentColor.color(selectionID: accentColorID, customHex: customAccentColorHex)
    }

    private var primaryTimerButtonSystemName: String {
        if completionSoundPlayer.isRinging {
            return "stop.fill"
        }

        return clock.isRunning ? "pause.fill" : "play.fill"
    }

    private var primaryTimerButtonColor: Color {
        completionSoundPlayer.isRinging ? .red : accentColor
    }

    private var primaryTimerButtonAccessibilityLabel: String {
        if completionSoundPlayer.isRinging {
            return "Stop ringing"
        }

        return clock.isRunning ? "Pause timer" : "Start timer"
    }

    var body: some View {
        ZStack {
            timerView

            if let activeTimerOverlay {
                overlay(for: activeTimerOverlay)
                    .zIndex(1)
            }
        }
        .frame(width: MainWindowScene.width, height: MainWindowScene.height)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea(edges: .top))
        .ignoresSafeArea(edges: .top)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            #if os(macOS)
            ZStack {
                MainWindowConfigurator(appearanceModeID: appearanceModeID)
                FocusTimerWindowCommandBridge(commandCenter: windowCommandCenter)

                FocusTimerMenuBarBridge(
                    clock: clock,
                    store: store,
                    updater: updater,
                    isEnabled: menuBarIconEnabled,
                    styleID: menuBarIconStyleID,
                    onOpenFloatingTimer: openFloatingTimerFromMenuBar,
                    onOpenSettings: {
                        windowCommandCenter.requestMainWindow(.settings)
                    }
                )
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            #endif
        }
        .onChange(of: clock.remainingSeconds) { remainingSeconds in
            guard !isEditingTimeText else { return }
            timeText = FocusTimerFormatting.clock(remainingSeconds)
        }
        .onChange(of: soundEnabled) { isEnabled in
            if !isEnabled {
                stopRinging()
            }
        }
        .onChange(of: completionNotificationEnabled) { isEnabled in
            if !isEnabled {
                FocusTimerCompletionNotification.clear()
            }
        }
        .onAppear {
            timeText = FocusTimerFormatting.clock(clock.remainingSeconds)
            handleMainWindowRequest()
        }
        .onChange(of: windowCommandCenter.mainWindowRequest?.id) { _ in
            handleMainWindowRequest()
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: activeTimerOverlay)
    }

    private var timerView: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: finishTimeEditing)

            VStack(spacing: 0) {
                ZStack {
                    Text("Focus Timer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack {
                        IconCircleButton(
                            systemName: "line.3.horizontal",
                            accessibilityLabel: "Saved timers",
                            action: {
                                finishTimeEditing()
                                activeTimerOverlay = .savedTimers
                            }
                        )

                        Spacer()

                        IconCircleButton(
                            systemName: "gearshape",
                            accessibilityLabel: "Settings",
                            action: {
                                finishTimeEditing()
                                activeTimerOverlay = .settings
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

                        stopRinging()
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
                                .onChange(of: isTimeFieldFocused) { isFocused in
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
                            stopRinging()
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
                            stopRinging()
                            clock.reset()
                        }
                    )

                    Button {
                        finishTimeEditing()

                        if completionSoundPlayer.isRinging {
                            stopRinging()
                        } else if clock.isRunning {
                            clock.pause()
                        } else {
                            store.recordUse(durationSeconds: clock.selectedSeconds)
                            clock.start()
                        }
                    } label: {
                        Image(systemName: primaryTimerButtonSystemName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(primaryTimerButtonColor, in: Circle())
                            .shadow(color: primaryTimerButtonColor.opacity(0.28), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(primaryTimerButtonAccessibilityLabel)

                    IconCircleButton(
                        systemName: "macwindow",
                        accessibilityLabel: "Open floating timer",
                        action: {
                            finishTimeEditing()
                            openWindow(id: FloatingTimerWindowScene.id)
                        }
                    )

                    IconCircleButton(
                        systemName: "plus",
                        accessibilityLabel: "Increase by five minutes",
                        action: {
                            finishTimeEditing()
                            stopRinging()
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
    private func overlay(for screen: TimerOverlay) -> some View {
        switch screen {
        case .savedTimers:
            SavedTimersOverlayView(
                store: store,
                accentColor: accentColor,
                onSelect: { timer in
                    stopRinging()
                    clock.setDuration(timer.durationSeconds)
                    store.recordUse(durationSeconds: timer.durationSeconds)
                    activeTimerOverlay = nil
                },
                onClose: {
                    activeTimerOverlay = nil
                }
            )
            .transition(.move(edge: .leading).combined(with: .opacity))

        case .settings:
            SettingsOverlayView(
                accentColorID: $accentColorID,
                customAccentColorHex: $customAccentColorHex,
                appearanceModeID: $appearanceModeID,
                soundEnabled: $soundEnabled,
                completionSoundID: $completionSoundID,
                customCompletionSoundName: $customCompletionSoundName,
                completionNotificationEnabled: $completionNotificationEnabled,
                menuBarIconEnabled: $menuBarIconEnabled,
                menuBarIconStyleID: $menuBarIconStyleID,
                floatingTimerOpacity: $floatingTimerOpacity,
                floatingTimerClickThrough: $floatingTimerClickThrough,
                updater: updater,
                store: store,
                onClose: {
                    activeTimerOverlay = nil
                }
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private func stopRinging() {
        #if os(macOS)
        completionSoundPlayer.stop()
        FocusTimerCompletionNotification.clear()
        #endif
    }

    private func openFloatingTimerFromMenuBar() {
        finishTimeEditing()
        openWindow(id: FloatingTimerWindowScene.id)

        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
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
        stopRinging()
        timeText = FocusTimerFormatting.clock(clock.remainingSeconds)
    }

    private func handleMainWindowRequest() {
        guard let request = windowCommandCenter.mainWindowRequest else { return }
        guard handledMainWindowRequestID != request.id else { return }

        handledMainWindowRequestID = request.id

        switch request.presentation {
        case .timer:
            break
        case .settings:
            finishTimeEditing()
            activeTimerOverlay = .settings
        }

        #if os(macOS)
        FocusTimerWindowLookup.bringToFront(id: MainWindowScene.id)
        #endif

        windowCommandCenter.finish(request)
    }
}

private enum TimerOverlay: Equatable {
    case savedTimers
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
            window.identifier = NSUserInterfaceItemIdentifier(MainWindowScene.id)
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
