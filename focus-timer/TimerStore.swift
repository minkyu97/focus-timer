import Foundation
import Combine

final class TimerStore: ObservableObject {
    private static let storageKey = "focusTimer.storedTimers"
    private static let maxRecentCount = 24

    @Published private(set) var timers: [StoredTimer] = [] {
        didSet { save() }
    }

    init() {
        load()
    }

    var pinnedTimers: [StoredTimer] {
        timers
            .filter(\.isPinned)
            .sorted { $0.durationSeconds > $1.durationSeconds }
    }

    var recentTimers: [StoredTimer] {
        timers
            .filter { !$0.isPinned }
            .sorted { $0.lastUsed > $1.lastUsed }
    }

    var sortedTimers: [StoredTimer] {
        return pinnedTimers + recentTimers
    }

    var lastUsedDurationSeconds: Int {
        timers
            .max { $0.lastUsed < $1.lastUsed }?
            .durationSeconds ?? FocusTimerClock.defaultDurationSeconds
    }

    var hasRecentTimers: Bool {
        timers.contains { !$0.isPinned }
    }

    func recordUse(durationSeconds: Int) {
        let durationSeconds = FocusTimerClock.clampedDuration(durationSeconds)

        if let index = timers.firstIndex(where: { $0.durationSeconds == durationSeconds }) {
            timers[index].lastUsed = Date()
        } else {
            timers.append(
                StoredTimer(
                    durationSeconds: durationSeconds,
                    isPinned: false,
                    lastUsed: Date()
                )
            )
        }

        trimRecentTimers()
    }

    func togglePinned(_ timer: StoredTimer) {
        if let index = timers.firstIndex(where: { $0.durationSeconds == timer.durationSeconds }) {
            timers[index].isPinned.toggle()
            timers[index].lastUsed = Date()
        } else {
            timers.append(
                StoredTimer(
                    durationSeconds: FocusTimerClock.clampedDuration(timer.durationSeconds),
                    isPinned: true,
                    lastUsed: Date()
                )
            )
        }
    }

    func clearRecentTimers() {
        timers.removeAll { !$0.isPinned }
    }

    func remove(_ timer: StoredTimer) {
        timers.removeAll { $0.durationSeconds == timer.durationSeconds }
    }

    private func trimRecentTimers() {
        let pinnedTimers = timers.filter(\.isPinned)
        let recentTimers = timers
            .filter { !$0.isPinned }
            .sorted { $0.lastUsed > $1.lastUsed }
            .prefix(Self.maxRecentCount)

        timers = pinnedTimers + recentTimers
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let decodedTimers = try? JSONDecoder().decode([StoredTimer].self, from: data)
        else {
            timers = []
            return
        }

        timers = decodedTimers
            .filter { (1...FocusTimerClock.maxDurationSeconds).contains($0.durationSeconds) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(timers) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
