import Foundation
import Combine

final class FocusTimerClock: ObservableObject {
    static let defaultDurationSeconds = 25 * 60
    static let maxDurationSeconds = 60 * 60
    private static let minDurationSeconds = 1

    @Published private(set) var selectedSeconds: Int
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var isRunning = false
    @Published private(set) var completionCount = 0

    private var targetDate: Date?
    private var ticker: AnyCancellable?

    init(initialSeconds: Int = defaultDurationSeconds) {
        let duration = Self.clampedDuration(initialSeconds)
        selectedSeconds = duration
        remainingSeconds = duration

        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self else { return }
                if self.tick(now) {
                    self.completionCount += 1
                }
            }
    }

    static func clampedDuration(_ seconds: Int) -> Int {
        min(max(seconds, minDurationSeconds), maxDurationSeconds)
    }

    func setDuration(_ seconds: Int) {
        let duration = Self.clampedDuration(seconds)
        selectedSeconds = duration
        remainingSeconds = duration
        isRunning = false
        targetDate = nil
    }

    func adjustDuration(by deltaSeconds: Int) {
        setDuration(selectedSeconds + deltaSeconds)
    }

    func start() {
        if remainingSeconds <= 0 {
            remainingSeconds = selectedSeconds
        }

        guard remainingSeconds > 0 else { return }
        targetDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
    }

    func pause() {
        _ = tick(Date())
        isRunning = false
        targetDate = nil
    }

    func reset() {
        remainingSeconds = selectedSeconds
        isRunning = false
        targetDate = nil
    }

    @discardableResult
    func tick(_ now: Date) -> Bool {
        guard isRunning, let targetDate else { return false }

        let remaining = max(0, Int(ceil(targetDate.timeIntervalSince(now))))
        remainingSeconds = remaining

        if remaining == 0 {
            isRunning = false
            self.targetDate = nil
            return true
        }

        return false
    }
}
