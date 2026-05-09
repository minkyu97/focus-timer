import SwiftUI

enum MainWindowScene {
    static let width: CGFloat = 340
    static let originalHeight: CGFloat = 530
    static let titlebarHeight: CGFloat = 32
    static let height = originalHeight - titlebarHeight
    static let headerTopPadding = titlebarHeight + 8
}

struct StoredTimer: Codable, Equatable, Identifiable {
    let durationSeconds: Int
    var isPinned: Bool
    var lastUsed: Date

    var id: Int { durationSeconds }
}

enum FocusTimerTheme: String, CaseIterable, Identifiable {
    case tomato
    case amber
    case mint
    case sky

    var id: String { rawValue }

    var name: String {
        switch self {
        case .tomato:
            return "Tomato"
        case .amber:
            return "Amber"
        case .mint:
            return "Mint"
        case .sky:
            return "Sky"
        }
    }

    var color: Color {
        switch self {
        case .tomato:
            return Color(red: 0.90, green: 0.20, blue: 0.16)
        case .amber:
            return Color(red: 0.95, green: 0.57, blue: 0.16)
        case .mint:
            return Color(red: 0.10, green: 0.64, blue: 0.49)
        case .sky:
            return Color(red: 0.14, green: 0.45, blue: 0.82)
        }
    }
}

enum FocusTimerFormatting {
    static func clock(_ totalSeconds: Int) -> String {
        let clampedSeconds = max(0, totalSeconds)
        let minutes = clampedSeconds / 60
        let seconds = clampedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func compactDuration(_ totalSeconds: Int) -> String {
        let clampedSeconds = max(0, totalSeconds)

        if clampedSeconds < 60 {
            return "\(clampedSeconds)s"
        }

        if clampedSeconds.isMultiple(of: 60) {
            return "\(clampedSeconds / 60)m"
        }

        return clock(clampedSeconds)
    }

    static func spokenDuration(_ totalSeconds: Int) -> String {
        let clampedSeconds = max(0, totalSeconds)
        let minutes = clampedSeconds / 60
        let seconds = clampedSeconds % 60

        if minutes == 0 {
            return seconds == 1 ? "1 second" : "\(seconds) seconds"
        }

        let minuteText = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        guard seconds > 0 else { return minuteText }

        let secondText = seconds == 1 ? "1 second" : "\(seconds) seconds"
        return "\(minuteText), \(secondText)"
    }

    static func seconds(fromTimeInput input: String) -> Int? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return nil }

        let parts = trimmedInput.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }

        let values = parts.compactMap { part -> Int? in
            guard !part.isEmpty, let value = Int(part), value >= 0 else { return nil }
            return value
        }

        guard values.count == parts.count else { return nil }

        switch values.count {
        case 1:
            return values[0] * 60
        case 2:
            return values[0] * 60 + values[1]
        case 3:
            return values[0] * 60 * 60 + values[1] * 60 + values[2]
        default:
            return nil
        }
    }
}
