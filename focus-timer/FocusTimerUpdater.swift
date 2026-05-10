import SwiftUI
import Combine

#if os(macOS)
import Sparkle

@MainActor
final class FocusTimerUpdater: ObservableObject {
    let updaterController: SPUStandardUpdaterController

    @Published private(set) var isConfigured = false
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var allowsAutomaticUpdates = false

    private var hasStartedUpdater = false
    private var observations: [NSKeyValueObservation] = []

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        observeUpdater()
        refreshState()
        startUpdaterIfConfigured()
    }

    func checkForUpdates() {
        guard isConfigured, canCheckForUpdates else { return }
        updaterController.checkForUpdates(nil)
        refreshState()
    }

    func setAutomaticallyChecksForUpdates(_ isEnabled: Bool) {
        guard isConfigured else { return }
        updaterController.updater.automaticallyChecksForUpdates = isEnabled
        refreshState()
    }

    func setAutomaticallyDownloadsUpdates(_ isEnabled: Bool) {
        guard isConfigured, allowsAutomaticUpdates else { return }
        updaterController.updater.automaticallyDownloadsUpdates = isEnabled
        refreshState()
    }

    private func startUpdaterIfConfigured() {
        guard isConfigured, !hasStartedUpdater else { return }

        hasStartedUpdater = true
        updaterController.startUpdater()
        refreshState()
    }

    private func observeUpdater() {
        let updater = updaterController.updater

        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.refreshState()
                }
            },
            updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.refreshState()
                }
            },
            updater.observe(\.automaticallyDownloadsUpdates, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.refreshState()
                }
            },
            updater.observe(\.allowsAutomaticUpdates, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.refreshState()
                }
            }
        ]
    }

    private func refreshState() {
        isConfigured = Self.hasRequiredConfiguration

        guard isConfigured else {
            canCheckForUpdates = false
            automaticallyChecksForUpdates = false
            automaticallyDownloadsUpdates = false
            allowsAutomaticUpdates = false
            return
        }

        let updater = updaterController.updater
        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        allowsAutomaticUpdates = updater.allowsAutomaticUpdates
    }

    private static var hasRequiredConfiguration: Bool {
        hasConfiguredInfoValue("SUFeedURL") && hasConfiguredInfoValue("SUPublicEDKey")
    }

    private static func hasConfiguredInfoValue(_ key: String) -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return false }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedValue.isEmpty
            && !trimmedValue.hasPrefix("$(")
            && !trimmedValue.localizedCaseInsensitiveContains("replace")
    }
}

struct CheckForUpdatesCommandView: View {
    @ObservedObject var updater: FocusTimerUpdater

    var body: some View {
        Button("Check for Updates...") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
#endif
