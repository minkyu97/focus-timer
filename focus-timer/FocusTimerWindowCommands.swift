import SwiftUI
import Combine

#if os(macOS)
import AppKit

enum FocusTimerMainWindowPresentation: Equatable {
    case landing
    case settings
}

struct FocusTimerMainWindowRequest: Equatable, Identifiable {
    let id = UUID()
    let presentation: FocusTimerMainWindowPresentation
}

@MainActor
final class FocusTimerWindowCommandCenter: ObservableObject {
    static let shared = FocusTimerWindowCommandCenter()

    @Published private(set) var mainWindowRequest: FocusTimerMainWindowRequest?

    private init() {}

    func requestMainWindow(_ presentation: FocusTimerMainWindowPresentation = .landing) {
        mainWindowRequest = FocusTimerMainWindowRequest(presentation: presentation)
    }

    func finish(_ request: FocusTimerMainWindowRequest) {
        guard mainWindowRequest?.id == request.id else { return }
        mainWindowRequest = nil
    }
}

struct FocusTimerWindowCommandBridge: View {
    @ObservedObject var commandCenter: FocusTimerWindowCommandCenter

    @Environment(\.openWindow) private var openWindow
    @State private var openedRequestID: UUID?

    var body: some View {
        Color.clear
            .onAppear(perform: openRequestedMainWindow)
            .onChange(of: commandCenter.mainWindowRequest?.id) { _, _ in
                openRequestedMainWindow()
            }
    }

    private func openRequestedMainWindow() {
        guard let request = commandCenter.mainWindowRequest else { return }
        guard openedRequestID != request.id else { return }

        openedRequestID = request.id
        openWindow(id: MainWindowScene.id)
        FocusTimerWindowLookup.bringToFront(id: MainWindowScene.id)
    }
}

@MainActor
final class FocusTimerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard flag else { return true }

        let hasVisibleMainWindow = FocusTimerWindowLookup.window(id: MainWindowScene.id) != nil
        guard !hasVisibleMainWindow else { return true }

        FocusTimerWindowCommandCenter.shared.requestMainWindow()
        return false
    }
}

enum FocusTimerWindowLookup {
    static func window(id: String) -> NSWindow? {
        NSApp.windows.first { window in
            window.isVisible && window.identifier?.rawValue == id
        }
    }

    static func bringToFront(id: String) {
        NSApp.activate(ignoringOtherApps: true)
        window(id: id)?.makeKeyAndOrderFront(nil)

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window(id: id)?.makeKeyAndOrderFront(nil)
        }
    }
}
#endif
