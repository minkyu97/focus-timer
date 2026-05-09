import SwiftUI
import Combine
import AppKit

struct FocusTimerMenuBarBridge: View {
    let clock: FocusTimerClock
    let store: TimerStore
    let isEnabled: Bool
    let styleID: String
    let onOpenMiniTimer: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Color.clear
            .onAppear(perform: updateMenuBar)
            .onChange(of: isEnabled) { _ in
                updateMenuBar()
            }
            .onChange(of: styleID) { _ in
                updateMenuBar()
            }
    }

    private func updateMenuBar() {
        FocusTimerMenuBarController.shared.configure(
            clock: clock,
            store: store,
            isEnabled: isEnabled,
            styleID: styleID,
            onOpenMiniTimer: onOpenMiniTimer,
            onOpenSettings: onOpenSettings
        )
    }
}

@MainActor
final class FocusTimerMenuBarController: NSObject {
    static let shared = FocusTimerMenuBarController()

    private weak var clock: FocusTimerClock?
    private weak var store: TimerStore?
    private var isEnabled = false
    private var styleID = FocusTimerMenuBarIconStyle.normal.rawValue
    private var statusItem: NSStatusItem?
    private var clockCancellable: AnyCancellable?
    private var renderedState: RenderedState?
    private var onOpenMiniTimer: (() -> Void)?
    private var onOpenSettings: (() -> Void)?

    private override init() {
        super.init()
    }

    func configure(
        clock: FocusTimerClock,
        store: TimerStore,
        isEnabled: Bool,
        styleID: String,
        onOpenMiniTimer: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        let clockChanged = self.clock !== clock
        self.clock = clock
        self.store = store
        self.isEnabled = isEnabled
        self.styleID = styleID
        self.onOpenMiniTimer = onOpenMiniTimer
        self.onOpenSettings = onOpenSettings

        if clockChanged {
            clockCancellable = clock.objectWillChange.sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        }

        refresh(force: true)
    }

    private func refresh(force: Bool = false) {
        guard isEnabled else {
            removeStatusItem()
            return
        }

        guard let clock else { return }

        let style = FocusTimerMenuBarIconStyle.resolved(from: styleID)
        let state = RenderedState(
            style: style,
            remainingSeconds: clock.remainingSeconds,
            isRunning: clock.isRunning
        )

        guard force || state != renderedState else { return }

        installStatusItemIfNeeded()
        renderedState = state
        updateButton(style: style, remainingSeconds: clock.remainingSeconds)
        updateMenu(clock: clock)
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.toolTip = "Focus Timer"
    }

    private func removeStatusItem() {
        renderedState = nil

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }

        statusItem = nil
    }

    private func updateButton(style: FocusTimerMenuBarIconStyle, remainingSeconds: Int) {
        guard let statusItem, let button = statusItem.button else { return }

        switch style {
        case .normal:
            statusItem.length = NSStatusItem.squareLength
            button.image = symbolImage("timer", accessibilityDescription: "Focus Timer")
            button.imagePosition = .imageOnly
            button.title = ""
        case .remainingTime:
            statusItem.length = NSStatusItem.variableLength
            button.image = nil
            button.imagePosition = .noImage
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            button.title = FocusTimerFormatting.clock(remainingSeconds)
        }
    }

    private func updateMenu(clock: FocusTimerClock) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let timeItem = NSMenuItem(title: FocusTimerFormatting.clock(clock.remainingSeconds), action: nil, keyEquivalent: "")
        timeItem.attributedTitle = NSAttributedString(
            string: FocusTimerFormatting.clock(clock.remainingSeconds),
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            ]
        )
        timeItem.isEnabled = false
        menu.addItem(timeItem)

        menu.addItem(.separator())

        let startPauseItem = NSMenuItem(
            title: clock.isRunning ? "Pause" : "Start",
            action: #selector(toggleTimer),
            keyEquivalent: ""
        )
        startPauseItem.target = self
        startPauseItem.image = symbolImage(clock.isRunning ? "pause.fill" : "play.fill")
        startPauseItem.isEnabled = true
        menu.addItem(startPauseItem)

        let resetItem = NSMenuItem(
            title: "Reset",
            action: #selector(resetTimer),
            keyEquivalent: ""
        )
        resetItem.target = self
        resetItem.image = symbolImage("arrow.counterclockwise")
        resetItem.isEnabled = true
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let miniWindowItem = NSMenuItem(
            title: "Open Mini Window",
            action: #selector(openMiniTimer),
            keyEquivalent: ""
        )
        miniWindowItem.target = self
        miniWindowItem.image = symbolImage("macwindow")
        miniWindowItem.isEnabled = onOpenMiniTimer != nil
        menu.addItem(miniWindowItem)

        let settingsItem = NSMenuItem(
            title: "Open Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = symbolImage("gearshape")
        settingsItem.isEnabled = onOpenSettings != nil
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Focus Timer",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func symbolImage(_ name: String, accessibilityDescription: String? = nil) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
        image?.isTemplate = true
        return image
    }

    @objc private func toggleTimer() {
        guard let clock else { return }

        if clock.isRunning {
            clock.pause()
        } else {
            store?.recordUse(durationSeconds: clock.selectedSeconds)
            clock.start()
        }

        refresh(force: true)
    }

    @objc private func resetTimer() {
        clock?.reset()
        refresh(force: true)
    }

    @objc private func openMiniTimer() {
        onOpenMiniTimer?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private struct RenderedState: Equatable {
        let style: FocusTimerMenuBarIconStyle
        let remainingSeconds: Int
        let isRunning: Bool
    }
}
