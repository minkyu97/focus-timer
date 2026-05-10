import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct SettingsOverlayView: View {
    @Binding var accentColorID: String
    @Binding var customAccentColorHex: String
    @Binding var appearanceModeID: String
    @Binding var soundEnabled: Bool
    @Binding var completionSoundID: String
    @Binding var customCompletionSoundName: String
    @Binding var completionNotificationEnabled: Bool
    @Binding var menuBarIconEnabled: Bool
    @Binding var menuBarIconStyleID: String
    @Binding var floatingTimerOpacity: Double
    @Binding var floatingTimerClickThrough: Bool
    @Binding var floatingTimerDisplayModeID: String

    @ObservedObject var updater: FocusTimerUpdater
    @ObservedObject var store: TimerStore

    let onClose: () -> Void

    private var selectedTheme: FocusTimerTheme? {
        FocusTimerTheme(rawValue: accentColorID)
    }

    private var selectedAccentColor: Color {
        FocusTimerAccentColor.color(selectionID: accentColorID, customHex: customAccentColorHex)
    }

    private var customAccentColor: Color? {
        FocusTimerAccentColor.customColor(from: customAccentColorHex)
    }

    private var isCustomColorSelected: Bool {
        accentColorID == FocusTimerAccentColor.customID && customAccentColor != nil
    }

    private var canRemoveSelectedSound: Bool {
        completionSoundID == FocusTimerCompletionSound.customID && !customCompletionSoundName.isEmpty
    }

    private var canEditUpdaterSettings: Bool {
        updater.isConfigured
    }

    private var canAutomaticallyDownloadUpdates: Bool {
        updater.isConfigured && updater.automaticallyChecksForUpdates && updater.allowsAutomaticUpdates
    }

    var body: some View {
        VStack(spacing: 0) {
            OverlayHeader(title: "Settings", onClose: onClose)

            ScrollView {
                VStack(spacing: 18) {
                    settingsGroup {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Disk Color")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 14) {
                                ForEach(FocusTimerTheme.allCases) { theme in
                                    Button {
                                        accentColorID = theme.rawValue
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(theme.color)
                                                .frame(width: 34, height: 34)

                                            if selectedTheme == theme {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .frame(width: 42, height: 42)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(theme.name)
                                }

                                customColorButton
                            }
                        }
                    }

                    settingsGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Appearance", systemImage: "circle.lefthalf.filled")
                                .font(.system(size: 14, weight: .medium))

                            Picker("Appearance", selection: $appearanceModeID) {
                                ForEach(FocusTimerAppearanceMode.allCases) { mode in
                                    Text(mode.name).tag(mode.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }

                    settingsGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            settingsToggleRow("Completion Sound", isOn: $soundEnabled) {
                                Label("Completion Sound", systemImage: "speaker.wave.2")
                                    .font(.system(size: 14, weight: .medium))
                            }

                            Picker("Finish Sound", selection: $completionSoundID) {
                                ForEach(FocusTimerCompletionSound.options(customSoundName: customCompletionSoundName)) { option in
                                    Text(option.name).tag(option.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .disabled(!soundEnabled)
                            .opacity(soundEnabled ? 1 : 0.45)

                            HStack(spacing: 12) {
                                Button {
                                    addCustomSound()
                                } label: {
                                    Label("Add Sound", systemImage: "plus.circle")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .buttonStyle(.borderless)
                                .disabled(!soundEnabled)
                                .opacity(soundEnabled ? 1 : 0.45)

                                Button {
                                    previewCompletionSound()
                                } label: {
                                    Label("Preview", systemImage: "play.circle")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .buttonStyle(.borderless)
                                .disabled(!soundEnabled)

                                Button {
                                    removeCustomSound()
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .buttonStyle(.borderless)
                                .disabled(!canRemoveSelectedSound)
                                .foregroundStyle(canRemoveSelectedSound ? Color.red : Color.secondary)
                                .opacity(canRemoveSelectedSound ? 1 : 0.28)
                            }

                            settingsToggleRow("Completion Notification", isOn: $completionNotificationEnabled) {
                                Label("Completion Notification", systemImage: "bell")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                    }

                    settingsGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .medium))

                            settingsToggleRow(
                                "Automatically Check for Updates",
                                isOn: automaticUpdateChecksBinding,
                                isEnabled: canEditUpdaterSettings
                            ) {
                                Text("Automatically Check for Updates")
                                    .font(.system(size: 14, weight: .medium))
                            }

                            settingsToggleRow(
                                "Download Updates Automatically",
                                isOn: automaticDownloadUpdatesBinding,
                                isEnabled: canAutomaticallyDownloadUpdates
                            ) {
                                Text("Download Updates Automatically")
                                    .font(.system(size: 14, weight: .medium))
                            }

                            Button {
                                updater.checkForUpdates()
                            } label: {
                                Label("Check for Updates", systemImage: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .buttonStyle(.borderless)
                            .disabled(!updater.canCheckForUpdates)
                            .opacity(updater.canCheckForUpdates ? 1 : 0.45)
                        }
                    }

                    settingsGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            settingsToggleRow("Menu Bar Icon", isOn: $menuBarIconEnabled) {
                                Label("Menu Bar Icon", systemImage: "menubar.rectangle")
                                    .font(.system(size: 14, weight: .medium))
                            }

                            Picker("Menu Bar Icon Type", selection: $menuBarIconStyleID) {
                                ForEach(FocusTimerMenuBarIconStyle.allCases) { style in
                                    Text(style.name).tag(style.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .disabled(!menuBarIconEnabled)
                            .opacity(menuBarIconEnabled ? 1 : 0.45)
                        }
                    }

                    settingsGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Floating Timer", systemImage: "macwindow")
                                .font(.system(size: 14, weight: .medium))

                            Picker("Floating Timer Display", selection: $floatingTimerDisplayModeID) {
                                ForEach(FocusTimerFloatingTimerDisplayMode.allCases) { mode in
                                    Text(mode.name).tag(mode.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            HStack {
                                Text("Opacity")
                                    .font(.system(size: 14, weight: .medium))

                                Spacer()

                                Text("\(Int(floatingTimerOpacity * 100))%")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $floatingTimerOpacity, in: 0.35...1, step: 0.05)
                                .tint(selectedAccentColor)

                            settingsToggleRow("Click-Through", isOn: $floatingTimerClickThrough) {
                                Label("Click-Through", systemImage: "cursorarrow")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                    }

                    settingsGroup {
                        Button {
                            store.clearRecentTimers()
                        } label: {
                            HStack {
                                Label("Clear Recent Timers", systemImage: "trash")
                                    .font(.system(size: 14, weight: .medium))

                                Spacer()
                            }
                            .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.timers.allSatisfy(\.isPinned))
                        .opacity(store.timers.allSatisfy(\.isPinned) ? 0.45 : 1)
                    }
                }
                .padding(18)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            completionSoundID = FocusTimerCompletionSound.normalizedSoundID(completionSoundID)
            floatingTimerDisplayModeID = FocusTimerFloatingTimerDisplayMode
                .resolved(from: floatingTimerDisplayModeID)
                .rawValue
        }
    }

    private var automaticUpdateChecksBinding: Binding<Bool> {
        Binding(
            get: { updater.automaticallyChecksForUpdates },
            set: { updater.setAutomaticallyChecksForUpdates($0) }
        )
    }

    private var automaticDownloadUpdatesBinding: Binding<Bool> {
        Binding(
            get: { updater.automaticallyDownloadsUpdates },
            set: { updater.setAutomaticallyDownloadsUpdates($0) }
        )
    }

    private var customColorButton: some View {
        Button {
            if customAccentColor != nil {
                accentColorID = FocusTimerAccentColor.customID
            }

            showCustomColorPicker()
        } label: {
            ZStack {
                Circle()
                    .fill(customAccentColor ?? Color.clear)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                isCustomColorSelected ? Color.primary.opacity(0.72) : Color.primary.opacity(0.26),
                                lineWidth: isCustomColorSelected ? 2 : 1
                            )
                    }

                Image(systemName: "pencil.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(customAccentColor == nil ? Color.secondary : Color.white)
                    .shadow(
                        color: customAccentColor == nil ? Color.clear : Color.black.opacity(0.38),
                        radius: 2,
                        y: 1
                    )
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Custom disk color")
    }

    private func showCustomColorPicker() {
        #if os(macOS)
        let initialColor = FocusTimerAccentColor.nsColor(fromHex: customAccentColorHex)
            ?? FocusTimerAccentColor.nsColor(from: selectedAccentColor)
            ?? .systemRed

        CustomAccentColorPanelController.shared.show(initialColor: initialColor) { color in
            guard let hexString = FocusTimerAccentColor.hexString(from: color) else { return }

            customAccentColorHex = hexString
            accentColorID = FocusTimerAccentColor.customID
        }
        #endif
    }

    private func addCustomSound() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio]
        panel.prompt = "Add"

        guard panel.runModal() == .OK, let soundURL = panel.url else { return }

        do {
            customCompletionSoundName = try FocusTimerCompletionSound.importCustomSound(from: soundURL)
            completionSoundID = FocusTimerCompletionSound.customID
        } catch {
            NSSound.beep()
        }
        #endif
    }

    private func previewCompletionSound() {
        #if os(macOS)
        FocusTimerCompletionSoundPlayer.shared.play(soundID: completionSoundID)
        #endif
    }

    private func removeCustomSound() {
        #if os(macOS)
        FocusTimerCompletionSound.removeCustomSound()
        customCompletionSoundName = ""

        if completionSoundID == FocusTimerCompletionSound.customID {
            completionSoundID = FocusTimerCompletionSound.systemAlertID
        }
        #endif
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private func settingsToggleRow<LabelContent: View>(
        _ accessibilityLabel: String,
        isOn: Binding<Bool>,
        isEnabled: Bool = true,
        @ViewBuilder label: () -> LabelContent
    ) -> some View {
        HStack(spacing: 12) {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(accessibilityLabel, isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

#if os(macOS)
private final class CustomAccentColorPanelController: NSObject {
    static let shared = CustomAccentColorPanelController()

    private var onColorChange: ((NSColor) -> Void)?

    func show(initialColor: NSColor, onChange: @escaping (NSColor) -> Void) {
        onColorChange = onChange

        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = initialColor
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        onColorChange?(sender.color)
    }
}
#endif
