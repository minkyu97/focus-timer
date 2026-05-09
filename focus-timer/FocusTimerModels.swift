import SwiftUI
import Combine

#if os(macOS)
import AppKit
#endif

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

enum FocusTimerAccentColor {
    static let customID = "custom"

    static func color(selectionID: String, customHex: String) -> Color {
        if selectionID == customID, let customColor = customColor(from: customHex) {
            return customColor
        }

        return (FocusTimerTheme(rawValue: selectionID) ?? .tomato).color
    }

    static func customColor(from hex: String) -> Color? {
        let normalizedHex = normalizedHexString(hex)
        guard normalizedHex.count == 6, let value = UInt64(normalizedHex, radix: 16) else {
            return nil
        }

        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    #if os(macOS)
    static func nsColor(from color: Color) -> NSColor? {
        NSColor(color).usingColorSpace(.sRGB)
    }

    static func nsColor(fromHex hex: String) -> NSColor? {
        guard let color = customColor(from: hex) else { return nil }
        return nsColor(from: color)
    }

    static func hexString(from color: NSColor) -> String? {
        guard let rgbColor = color.usingColorSpace(.sRGB) else { return nil }

        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
    #endif

    private static func normalizedHexString(_ hex: String) -> String {
        hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
    }
}

enum FocusTimerAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case dark
    case white

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system:
            return "System"
        case .dark:
            return "Dark"
        case .white:
            return "White"
        }
    }

    static func resolved(from rawValue: String) -> FocusTimerAppearanceMode {
        FocusTimerAppearanceMode(rawValue: rawValue) ?? .system
    }

    func resolvedColorScheme(systemColorScheme: ColorScheme) -> ColorScheme {
        switch self {
        case .system:
            return systemColorScheme
        case .dark:
            return .dark
        case .white:
            return .light
        }
    }

    #if os(macOS)
    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .white:
            return NSAppearance(named: .aqua)
        }
    }
    #endif
}

enum FocusTimerMenuBarIconStyle: String, CaseIterable, Identifiable {
    case normal
    case remainingTime

    var id: String { rawValue }

    var name: String {
        switch self {
        case .normal:
            return "Normal"
        case .remainingTime:
            return "Time"
        }
    }

    static func resolved(from rawValue: String) -> FocusTimerMenuBarIconStyle {
        FocusTimerMenuBarIconStyle(rawValue: rawValue) ?? .normal
    }
}

#if os(macOS)
@MainActor
final class FocusTimerSystemAppearance: ObservableObject {
    @Published private(set) var colorScheme = FocusTimerSystemAppearance.currentColorScheme()

    private var observers: [NSObjectProtocol] = []

    init() {
        observers = [
            DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                let observer = self
                Task { @MainActor in
                    observer?.refresh()
                }
            },
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                let observer = self
                Task { @MainActor in
                    observer?.refresh()
                }
            }
        ]
    }

    deinit {
        observers.forEach { observer in
            DistributedNotificationCenter.default().removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func refresh() {
        let latestColorScheme = FocusTimerSystemAppearance.currentColorScheme()
        guard colorScheme != latestColorScheme else { return }

        colorScheme = latestColorScheme
    }

    private static func currentColorScheme() -> ColorScheme {
        let bestMatch = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return bestMatch == .darkAqua ? .dark : .light
    }
}

enum FocusTimerWindowAppearance {
    static func apply(modeID: String, to window: NSWindow) {
        let appearance = FocusTimerAppearanceMode.resolved(from: modeID).nsAppearance
        window.appearance = appearance
        window.contentView?.appearance = appearance

        if let appearance {
            appearance.performAsCurrentDrawingAppearance {
                updateBackground(for: window)
            }
        } else {
            updateBackground(for: window)
        }
    }

    private static func updateBackground(for window: NSWindow) {
        window.backgroundColor = .windowBackgroundColor
        window.contentView?.layer?.backgroundColor = nil
        window.contentView?.needsDisplay = true
    }
}

final class FocusTimerAppearanceView: NSView {
    var onWindowOrAppearanceChange: ((FocusTimerAppearanceView) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowOrAppearanceChange?(self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onWindowOrAppearanceChange?(self)
    }
}
#endif

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
