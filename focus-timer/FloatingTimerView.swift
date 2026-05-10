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
    let displayModeID: String
    let appearanceModeID: String
    let menuBarIconEnabled: Bool
    let menuBarIconStyleID: String

    private var displayMode: FocusTimerFloatingTimerDisplayMode {
        FocusTimerFloatingTimerDisplayMode.resolved(from: displayModeID)
    }

    private var layout: FloatingTimerLayout {
        FloatingTimerLayout(mode: displayMode)
    }

    var body: some View {
        VStack(spacing: 6) {
            #if os(macOS)
            FloatingTimerDragStrip { view, location in
                FocusTimerMenuBarController.shared.popUpContextMenu(at: location, in: view)
            }
                .frame(height: 24)
            #else
            Color.clear
                .frame(height: 24)
            #endif

            if displayMode.showsDisk {
                TimerDiskView(
                    remainingSeconds: clock.remainingSeconds,
                    selectedSeconds: clock.selectedSeconds,
                    accentColor: accentColor,
                    isRunning: clock.isRunning,
                    onDurationChange: { _ in }
                )
                .frame(width: layout.diskSize, height: layout.diskSize)
                .allowsHitTesting(false)
            }

            if displayMode.showsTime {
                Text(FocusTimerFormatting.clock(clock.remainingSeconds))
                    .font(.system(size: layout.timeFontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, layout.bottomPadding)
        .frame(width: layout.windowSize.width, height: layout.windowSize.height)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea(edges: .top))
        .ignoresSafeArea(edges: .top)
        .overlay {
            ZStack {
                FloatingTimerWindowConfigurator(
                    opacity: windowOpacity,
                    clickThroughEnabled: clickThroughEnabled,
                    contentSize: layout.windowSize,
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

private struct FloatingTimerLayout {
    let windowSize: CGSize
    let diskSize: CGFloat
    let timeFontSize: CGFloat
    let bottomPadding: CGFloat

    init(mode: FocusTimerFloatingTimerDisplayMode) {
        switch mode {
        case .diskAndTime:
            windowSize = CGSize(width: FloatingTimerWindowScene.width, height: FloatingTimerWindowScene.height)
            diskSize = 150
            timeFontSize = 34
            bottomPadding = 6
        case .diskOnly:
            windowSize = CGSize(width: FloatingTimerWindowScene.width, height: 190)
            diskSize = 150
            timeFontSize = 34
            bottomPadding = 10
        case .timeOnly:
            windowSize = CGSize(width: FloatingTimerWindowScene.width, height: 96)
            diskSize = 150
            timeFontSize = 38
            bottomPadding = 12
        }
    }
}

private extension FocusTimerFloatingTimerDisplayMode {
    var showsDisk: Bool {
        switch self {
        case .diskAndTime, .diskOnly:
            return true
        case .timeOnly:
            return false
        }
    }

    var showsTime: Bool {
        switch self {
        case .diskAndTime, .timeOnly:
            return true
        case .diskOnly:
            return false
        }
    }
}

#if os(macOS)
private struct FloatingTimerDragStrip: NSViewRepresentable {
    let onMenuRequest: (NSView, NSPoint) -> Void

    func makeNSView(context: Context) -> NSView {
        DragStripView(onMenuRequest: onMenuRequest)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let dragStripView = nsView as? DragStripView else { return }
        dragStripView.onMenuRequest = onMenuRequest
    }

    private final class DragStripView: NSView {
        var onMenuRequest: (NSView, NSPoint) -> Void

        init(onMenuRequest: @escaping (NSView, NSPoint) -> Void) {
            self.onMenuRequest = onMenuRequest
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var mouseDownCanMoveWindow: Bool { false }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            if let window {
                window.performDrag(with: event)
            }
        }

        override func rightMouseDown(with event: NSEvent) {
            onMenuRequest(self, convert(event.locationInWindow, from: nil))
        }
    }
}

private struct FloatingTimerWindowConfigurator: NSViewRepresentable {
    let opacity: Double
    let clickThroughEnabled: Bool
    let contentSize: CGSize
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
                contentSize: contentSize,
                dragStripHeight: dragStripHeight,
                appearanceModeID: appearanceModeID
            )
        }
        context.coordinator.update(
            from: view,
            opacity: opacity,
            clickThroughEnabled: clickThroughEnabled,
            contentSize: contentSize,
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
                    contentSize: contentSize,
                    dragStripHeight: dragStripHeight,
                    appearanceModeID: appearanceModeID
                )
            }
        }

        context.coordinator.update(
            from: nsView,
            opacity: opacity,
            clickThroughEnabled: clickThroughEnabled,
            contentSize: contentSize,
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
            contentSize: CGSize,
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
                        contentSize: contentSize,
                        dragStripHeight: dragStripHeight,
                        appearanceModeID: appearanceModeID
                    )
                }
                return
            }

            self.window = window
            configure(window, contentSize: contentSize, appearanceModeID: appearanceModeID)

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

        private func configure(_ window: NSWindow, contentSize: CGSize, appearanceModeID: String) {
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
            resize(window, to: contentSize)
        }

        private func resize(_ window: NSWindow, to contentSize: CGSize) {
            let targetSize = NSSize(width: contentSize.width, height: contentSize.height)
            guard abs(window.frame.width - targetSize.width) > 0.5 ||
                abs(window.frame.height - targetSize.height) > 0.5 else {
                return
            }

            let targetFrame = NSRect(
                x: window.frame.minX,
                y: window.frame.maxY - targetSize.height,
                width: targetSize.width,
                height: targetSize.height
            )
            window.setFrame(targetFrame, display: true)
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
