import SwiftUI

#if os(macOS)
import AppKit
#endif

enum FloatingTimerWindowScene {
    static let id = "floating-timer"
    static let width: CGFloat = 198
    static let height: CGFloat = 224
    static let dragStripHitHeight: CGFloat = 32
}

struct FloatingTimerView: View {
    @ObservedObject var clock: FocusTimerClock
    @ObservedObject var store: TimerStore
    @ObservedObject var windowCommandCenter: FocusTimerWindowCommandCenter
    @ObservedObject var updater: FocusTimerUpdater

    @Environment(\.openWindow) private var openWindow

    let accentColor: Color
    let windowOpacity: Double
    let clickThroughEnabled: Bool
    let appearanceModeID: String
    let menuBarIconEnabled: Bool
    let menuBarIconStyleID: String

    var body: some View {
        VStack(spacing: 6) {
            #if os(macOS)
            FloatingTimerDragStrip()
                .frame(height: 24)
            #else
            Color.clear
                .frame(height: 24)
            #endif

            TimerDiskView(
                remainingSeconds: clock.remainingSeconds,
                selectedSeconds: clock.selectedSeconds,
                accentColor: accentColor,
                isRunning: clock.isRunning,
                onDurationChange: { _ in }
            )
            .frame(width: 150, height: 150)
            .allowsHitTesting(false)

            Text(FocusTimerFormatting.clock(clock.remainingSeconds))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .frame(width: FloatingTimerWindowScene.width, height: FloatingTimerWindowScene.height)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea(edges: .top))
        .ignoresSafeArea(edges: .top)
        .overlay {
            ZStack {
                FloatingTimerWindowConfigurator(
                    opacity: windowOpacity,
                    clickThroughEnabled: clickThroughEnabled,
                    dragStripHeight: FloatingTimerWindowScene.dragStripHitHeight,
                    appearanceModeID: appearanceModeID
                )
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
        }
    }

    private func openFloatingTimerFromMenuBar() {
        openWindow(id: FloatingTimerWindowScene.id)

        #if os(macOS)
        FocusTimerWindowLookup.bringToFront(id: FloatingTimerWindowScene.id)
        #endif
    }
}

#if os(macOS)
private struct FloatingTimerDragStrip: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragStripView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragStripView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }
}

private struct FloatingTimerWindowConfigurator: NSViewRepresentable {
    let opacity: Double
    let clickThroughEnabled: Bool
    let dragStripHeight: CGFloat
    let appearanceModeID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = FocusTimerAppearanceView()
        view.onWindowOrAppearanceChange = { view in
            context.coordinator.update(
                from: view,
                opacity: opacity,
                clickThroughEnabled: clickThroughEnabled,
                dragStripHeight: dragStripHeight,
                appearanceModeID: appearanceModeID
            )
        }
        context.coordinator.update(
            from: view,
            opacity: opacity,
            clickThroughEnabled: clickThroughEnabled,
            dragStripHeight: dragStripHeight,
            appearanceModeID: appearanceModeID
        )
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let nsView = nsView as? FocusTimerAppearanceView {
            nsView.onWindowOrAppearanceChange = { view in
                context.coordinator.update(
                    from: view,
                    opacity: opacity,
                    clickThroughEnabled: clickThroughEnabled,
                    dragStripHeight: dragStripHeight,
                    appearanceModeID: appearanceModeID
                )
            }
        }

        context.coordinator.update(
            from: nsView,
            opacity: opacity,
            clickThroughEnabled: clickThroughEnabled,
            dragStripHeight: dragStripHeight,
            appearanceModeID: appearanceModeID
        )
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstallMonitors()
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var opacity: Double = 1
        private var clickThroughEnabled = false
        private var dragStripHeight: CGFloat = 32
        private var monitors: [Any] = []

        func update(
            from view: NSView,
            opacity: Double,
            clickThroughEnabled: Bool,
            dragStripHeight: CGFloat,
            appearanceModeID: String
        ) {
            self.opacity = opacity
            self.clickThroughEnabled = clickThroughEnabled
            self.dragStripHeight = dragStripHeight

            guard let window = view.window else {
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.update(
                        from: view,
                        opacity: opacity,
                        clickThroughEnabled: clickThroughEnabled,
                        dragStripHeight: dragStripHeight,
                        appearanceModeID: appearanceModeID
                    )
                }
                return
            }

            self.window = window
            configure(window, appearanceModeID: appearanceModeID)

            if clickThroughEnabled {
                installMonitors()
            } else {
                uninstallMonitors()
            }

            updateMousePolicy()
        }

        func uninstallMonitors() {
            monitors.forEach(NSEvent.removeMonitor)
            monitors.removeAll()
            window?.ignoresMouseEvents = false
        }

        private func configure(_ window: NSWindow, appearanceModeID: String) {
            window.identifier = NSUserInterfaceItemIdentifier(FloatingTimerWindowScene.id)
            window.level = .floating
            window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
            window.isMovableByWindowBackground = true
            window.acceptsMouseMovedEvents = true
            window.alphaValue = CGFloat(min(max(opacity, 0.35), 1))
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

        private func installMonitors() {
            guard monitors.isEmpty else { return }

            let eventMask: NSEvent.EventTypeMask = [
                .mouseMoved,
                .leftMouseDown,
                .rightMouseDown,
                .otherMouseDown,
                .leftMouseDragged,
                .rightMouseDragged,
                .otherMouseDragged
            ]

            if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask, handler: { [weak self] event in
                self?.updateMousePolicy()
                return event
            }) {
                monitors.append(localMonitor)
            }

            if let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask, handler: { [weak self] _ in
                self?.updateMousePolicy()
            }) {
                monitors.append(globalMonitor)
            }
        }

        private func updateMousePolicy() {
            guard let window else { return }

            guard clickThroughEnabled else {
                window.ignoresMouseEvents = false
                return
            }

            let mouseLocation = NSEvent.mouseLocation
            let windowFrame = window.frame
            let dragStripFrame = CGRect(
                x: windowFrame.minX,
                y: windowFrame.maxY - dragStripHeight,
                width: windowFrame.width,
                height: dragStripHeight
            )

            window.ignoresMouseEvents = !dragStripFrame.contains(mouseLocation)
        }
    }
}
#endif
