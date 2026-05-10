import SwiftUI
import Combine
import AppKit

struct FocusTimerMenuBarBridge: View {
    let clock: FocusTimerClock
    let store: TimerStore
    let isEnabled: Bool
    let styleID: String
    let onOpenFloatingTimer: () -> Void
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
            onOpenFloatingTimer: onOpenFloatingTimer,
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
    private var storeCancellable: AnyCancellable?
    private var renderedState: RenderedState?
    private var onOpenFloatingTimer: (() -> Void)?
    private var onOpenSettings: (() -> Void)?
    private let maxInstantStartRecentCount = 5

    private override init() {
        super.init()
    }

    func configure(
        clock: FocusTimerClock,
        store: TimerStore,
        isEnabled: Bool,
        styleID: String,
        onOpenFloatingTimer: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        let clockChanged = self.clock !== clock
        let storeChanged = self.store !== store
        self.clock = clock
        self.store = store
        self.isEnabled = isEnabled
        self.styleID = styleID
        self.onOpenFloatingTimer = onOpenFloatingTimer
        self.onOpenSettings = onOpenSettings

        if clockChanged {
            clockCancellable = clock.objectWillChange.sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        }

        if storeChanged {
            storeCancellable = store.objectWillChange.sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh(force: true)
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
        addInstantStartSection(to: menu)

        menu.addItem(.separator())

        let floatingTimerItem = NSMenuItem(
            title: "Open Floating Timer",
            action: #selector(openFloatingTimer),
            keyEquivalent: ""
        )
        floatingTimerItem.target = self
        floatingTimerItem.image = symbolImage("macwindow")
        floatingTimerItem.isEnabled = onOpenFloatingTimer != nil
        menu.addItem(floatingTimerItem)

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

    private func addInstantStartSection(to menu: NSMenu) {
        let headerItem = NSMenuItem(title: "Instant Start", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        guard let store else {
            addEmptyInstantStartItem(to: menu)
            return
        }

        let timers = store.pinnedTimers + Array(store.recentTimers.prefix(maxInstantStartRecentCount))

        guard !timers.isEmpty else {
            addEmptyInstantStartItem(to: menu)
            return
        }

        for timer in timers {
            let item = NSMenuItem(
                title: FocusTimerFormatting.compactDuration(timer.durationSeconds),
                action: #selector(instantStartTimer(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = timer.durationSeconds
            item.image = symbolImage(timer.isPinned ? "heart.fill" : "clock.arrow.circlepath")
            item.toolTip = timer.isPinned ? "Pinned timer" : "Recent timer"
            item.isEnabled = true
            menu.addItem(item)
        }

        let clearRecentItem = NSMenuItem(
            title: "Clear Recent Timers",
            action: #selector(clearRecentTimers),
            keyEquivalent: ""
        )
        clearRecentItem.target = self
        clearRecentItem.image = symbolImage("trash")
        clearRecentItem.isEnabled = store.hasRecentTimers
        menu.addItem(clearRecentItem)
    }

    private func addEmptyInstantStartItem(to menu: NSMenu) {
        let emptyItem = NSMenuItem(title: "No saved timers", action: nil, keyEquivalent: "")
        emptyItem.isEnabled = false
        menu.addItem(emptyItem)
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

    @objc private func instantStartTimer(_ sender: NSMenuItem) {
        guard let durationSeconds = sender.representedObject as? Int, let clock else { return }

        FocusTimerCompletionSoundPlayer.shared.stop()
        FocusTimerCompletionNotification.clear()
        clock.setDuration(durationSeconds)
        store?.recordUse(durationSeconds: durationSeconds)
        clock.start()
        refresh(force: true)
    }

    @objc private func clearRecentTimers() {
        store?.clearRecentTimers()
        refresh(force: true)
    }

    @objc private func openFloatingTimer() {
        onOpenFloatingTimer?()
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
