import SwiftUI
import Combine

#if os(macOS)
import AppKit
@preconcurrency import UserNotifications
#endif

enum MainWindowScene {
    static let id = "main-window"
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

enum FocusTimerFloatingTimerDisplayMode: String, CaseIterable, Identifiable {
    case diskAndTime
    case diskOnly
    case timeOnly

    var id: String { rawValue }

    var name: String {
        switch self {
        case .diskAndTime:
            return "Disk + Time"
        case .diskOnly:
            return "Disk"
        case .timeOnly:
            return "Time"
        }
    }

    static func resolved(from rawValue: String) -> FocusTimerFloatingTimerDisplayMode {
        FocusTimerFloatingTimerDisplayMode(rawValue: rawValue) ?? .diskAndTime
    }
}

enum FocusTimerPreferenceMigration {
    static func migrateLegacyKeys() {
        let userDefaults = UserDefaults.standard
        migrateValue(
            from: "focusTimer.miniWindowOpacity",
            to: "focusTimer.floatingTimerOpacity",
            in: userDefaults
        )
        migrateValue(
            from: "focusTimer.miniWindowClickThrough",
            to: "focusTimer.floatingTimerClickThrough",
            in: userDefaults
        )
    }

    private static func migrateValue(from legacyKey: String, to currentKey: String, in userDefaults: UserDefaults) {
        guard userDefaults.object(forKey: currentKey) == nil else { return }
        guard let value = userDefaults.object(forKey: legacyKey) else { return }

        userDefaults.set(value, forKey: currentKey)
    }
}

struct FocusTimerCompletionSoundOption: Identifiable, Equatable {
    let id: String
    let name: String
}

enum FocusTimerCompletionSound {
    static let systemAlertID = "timer:Radial"
    static let customID = "custom"
    static let customFileNameDefaultsKey = "focusTimer.customCompletionSoundFileName"

    private static let legacySystemAlertID = "system-alert"

    private static let timerSoundFiles = [
        (name: "Radial", fileName: "Radial-EncoreInfinitum.m4r"),
        (name: "Arpeggio", fileName: "Arpeggio-EncoreInfinitum.m4r"),
        (name: "Breaking", fileName: "Breaking-EncoreInfinitum.m4r"),
        (name: "Canopy", fileName: "Canopy-EncoreInfinitum.m4r"),
        (name: "Chalet", fileName: "Chalet-EncoreInfinitum.m4r"),
        (name: "Chirp", fileName: "Chirp-EncoreInfinitum.m4r"),
        (name: "Daybreak", fileName: "Daybreak-EncoreInfinitum.m4r"),
        (name: "Departure", fileName: "Departure-EncoreInfinitum.m4r"),
        (name: "Dollop", fileName: "Dollop-EncoreInfinitum.m4r"),
        (name: "Journey", fileName: "Journey-EncoreInfinitum.m4r"),
        (name: "Kettle", fileName: "Kettle-EncoreInfinitum.m4r"),
        (name: "Mercury", fileName: "Mercury-EncoreInfinitum.m4r"),
        (name: "Milky Way", fileName: "Milky Way-EncoreInfinitum.m4r"),
        (name: "Quad", fileName: "Quad-EncoreInfinitum.m4r"),
        (name: "Reflection", fileName: "Reflection-EncoreInfinitum.m4r"),
        (name: "Scavenger", fileName: "Scavenger-EncoreInfinitum.m4r"),
        (name: "Seedling", fileName: "Seedling-EncoreInfinitum.m4r"),
        (name: "Shelter", fileName: "Shelter-EncoreInfinitum.m4r"),
        (name: "Sprinkles", fileName: "Sprinkles-EncoreInfinitum.m4r"),
        (name: "Steps", fileName: "Steps-EncoreInfinitum.m4r"),
        (name: "Storytime", fileName: "Storytime-EncoreInfinitum.m4r"),
        (name: "Tease", fileName: "Tease-EncoreInfinitum.m4r"),
        (name: "Tilt", fileName: "Tilt-EncoreInfinitum.m4r"),
        (name: "Unfold", fileName: "Unfold-EncoreInfinitum.m4r"),
        (name: "Valley", fileName: "Valley-EncoreInfinitum.m4r")
    ]

    static func timerSoundID(_ name: String) -> String {
        "timer:\(name)"
    }

    static func normalizedSoundID(_ id: String) -> String {
        if id == legacySystemAlertID {
            return systemAlertID
        }

        if id == customID || timerSoundFileName(from: id) != nil {
            return id
        }

        return systemAlertID
    }

    static func options(customSoundName: String) -> [FocusTimerCompletionSoundOption] {
        var options = timerSoundFiles.map { sound in
            FocusTimerCompletionSoundOption(
                id: timerSoundID(sound.name),
                name: sound.name == "Radial" ? "Radial (Default)" : sound.name
            )
        }

        if !customSoundName.isEmpty {
            options.append(FocusTimerCompletionSoundOption(id: customID, name: customSoundName))
        }

        return options
    }

    private static func timerSoundFileName(from id: String) -> String? {
        let prefix = "timer:"
        guard id.hasPrefix(prefix) else { return nil }

        let name = String(id.dropFirst(prefix.count))
        return timerSoundFiles.first { $0.name == name }?.fileName
    }

    #if os(macOS)
    static func timerSoundURL(from id: String) -> URL? {
        guard let fileName = timerSoundFileName(from: normalizedSoundID(id)) else {
            return nil
        }

        let url = URL(
            fileURLWithPath: "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/Ringtones",
            isDirectory: true
        )
        .appendingPathComponent(fileName)

        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func importCustomSound(from sourceURL: URL) throws -> String {
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let soundsDirectory = try customSoundsDirectory()
        try fileManager.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)

        if let previousFileName = UserDefaults.standard.string(forKey: customFileNameDefaultsKey) {
            try? fileManager.removeItem(at: soundsDirectory.appendingPathComponent(previousFileName))
        }

        let fileExtension = sourceURL.pathExtension.isEmpty ? "sound" : sourceURL.pathExtension
        let destinationFileName = "completion-sound.\(fileExtension)"
        let destinationURL = soundsDirectory.appendingPathComponent(destinationFileName)

        try? fileManager.removeItem(at: destinationURL)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        UserDefaults.standard.set(destinationFileName, forKey: customFileNameDefaultsKey)

        return sourceURL.deletingPathExtension().lastPathComponent
    }

    static func customSoundURL() -> URL? {
        guard let fileName = UserDefaults.standard.string(forKey: customFileNameDefaultsKey) else {
            return nil
        }

        return try? customSoundsDirectory().appendingPathComponent(fileName)
    }

    static func removeCustomSound() {
        let userDefaults = UserDefaults.standard

        if let fileName = userDefaults.string(forKey: customFileNameDefaultsKey),
           let soundsDirectory = try? customSoundsDirectory() {
            try? FileManager.default.removeItem(at: soundsDirectory.appendingPathComponent(fileName))
        }

        userDefaults.removeObject(forKey: customFileNameDefaultsKey)
    }

    private static func customSoundsDirectory() throws -> URL {
        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupportURL
            .appendingPathComponent("Focus Timer", isDirectory: true)
            .appendingPathComponent("Sounds", isDirectory: true)
    }
    #endif
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
        let bestMatch = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
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

@MainActor
final class FocusTimerCompletionSoundPlayer: ObservableObject {
    static let shared = FocusTimerCompletionSoundPlayer()

    @Published private(set) var isRinging = false

    private var activeSound: NSSound?
    private var activePlaybackID: UUID?

    private init() {}

    func play(soundID: String) {
        stop()

        let normalizedSoundID = FocusTimerCompletionSound.normalizedSoundID(soundID)

        if normalizedSoundID == FocusTimerCompletionSound.customID {
            guard let sound = customSound() else {
                NSSound.beep()
                return
            }

            play(sound)
            return
        }

        guard let timerSoundURL = FocusTimerCompletionSound.timerSoundURL(from: normalizedSoundID) else {
            NSSound.beep()
            return
        }

        guard let sound = NSSound(contentsOf: timerSoundURL, byReference: true) else {
            NSSound.beep()
            return
        }

        play(sound)
    }

    func stop() {
        activeSound?.stop()
        activeSound = nil
        activePlaybackID = nil
        isRinging = false
    }

    private func play(_ sound: NSSound) {
        let playbackID = UUID()
        activePlaybackID = playbackID
        activeSound = sound

        guard sound.play() else {
            stop()
            return
        }

        isRinging = true

        guard sound.duration.isFinite, sound.duration > 0 else { return }
        let playbackDuration = sound.duration + 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + playbackDuration) { [weak self, weak sound] in
            Task { @MainActor in
                guard let self, let sound else { return }
                self.finishPlaybackIfNeeded(sound, playbackID: playbackID)
            }
        }
    }

    private func finishPlaybackIfNeeded(_ sound: NSSound, playbackID: UUID) {
        guard activePlaybackID == playbackID, activeSound === sound, !sound.isPlaying else { return }

        activeSound = nil
        activePlaybackID = nil
        isRinging = false
    }

    private func customSound() -> NSSound? {
        guard let customSoundURL = FocusTimerCompletionSound.customSoundURL() else { return nil }
        guard FileManager.default.fileExists(atPath: customSoundURL.path) else { return nil }

        return NSSound(contentsOf: customSoundURL, byReference: false)
    }
}

@MainActor
final class FocusTimerCompletionController {
    static let shared = FocusTimerCompletionController()

    private let userDefaults = UserDefaults.standard
    private var clock: FocusTimerClock?
    private var clockCancellable: AnyCancellable?
    private var userDefaultsCancellable: AnyCancellable?
    private var lastCompletionCount = 0

    private init() {
        userDefaultsCancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: userDefaults)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleSettingsChange()
                }
            }
    }

    func configure(clock: FocusTimerClock) {
        guard self.clock !== clock else { return }

        self.clock = clock
        lastCompletionCount = clock.completionCount
        clockCancellable = clock.$completionCount.sink { [weak self] completionCount in
            Task { @MainActor in
                self?.handleCompletionCount(completionCount)
            }
        }
    }

    private func handleCompletionCount(_ completionCount: Int) {
        guard completionCount > lastCompletionCount else {
            lastCompletionCount = completionCount
            return
        }

        lastCompletionCount = completionCount

        guard soundEnabled else { return }

        FocusTimerCompletionSoundPlayer.shared.play(soundID: completionSoundID)

        if completionNotificationEnabled {
            FocusTimerCompletionNotification.post()
        }
    }

    private func handleSettingsChange() {
        if !soundEnabled {
            FocusTimerCompletionSoundPlayer.shared.stop()
            FocusTimerCompletionNotification.clear()
        }

        if !completionNotificationEnabled {
            FocusTimerCompletionNotification.clear()
        }
    }

    private var soundEnabled: Bool {
        boolSetting(forKey: "focusTimer.soundEnabled", defaultValue: true)
    }

    private var completionSoundID: String {
        userDefaults.string(forKey: "focusTimer.completionSoundID") ?? FocusTimerCompletionSound.systemAlertID
    }

    private var completionNotificationEnabled: Bool {
        boolSetting(forKey: "focusTimer.completionNotificationEnabled", defaultValue: true)
    }

    private func boolSetting(forKey key: String, defaultValue: Bool) -> Bool {
        guard userDefaults.object(forKey: key) != nil else { return defaultValue }
        return userDefaults.bool(forKey: key)
    }
}

enum FocusTimerCompletionNotification {
    nonisolated static let notificationID = "focusTimer.timerComplete.notification"
    nonisolated static let categoryID = "focusTimer.timerComplete.category"
    nonisolated static let stopActionID = "focusTimer.timerComplete.stopRinging"

    nonisolated static func configure() {
        let stopAction = UNNotificationAction(
            identifier: stopActionID,
            title: "Stop Ringing",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [stopAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    nonisolated static func post() {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                deliver(using: center)
            case .notDetermined:
                center.requestAuthorization(options: [.alert]) { isGranted, _ in
                    guard isGranted else { return }
                    deliver(using: center)
                }
            default:
                break
            }
        }
    }

    nonisolated static func clear() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID])
    }

    private nonisolated static func deliver(using center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = "Timer Finished"
        content.body = "Click to stop ringing."
        content.categoryIdentifier = categoryID
        content.sound = nil

        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: nil)
        clear()
        center.add(request)
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
