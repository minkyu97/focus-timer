//
//  focus_timerApp.swift
//  focus-timer
//
//  Created by minkyu on 5/8/26.
//

import SwiftUI

@main
struct focus_timerApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(FocusTimerAppDelegate.self) private var appDelegate
    @StateObject private var windowCommandCenter = FocusTimerWindowCommandCenter.shared
    #endif

    @StateObject private var clock: FocusTimerClock
    @StateObject private var store: TimerStore
    @StateObject private var systemAppearance = FocusTimerSystemAppearance()

    @AppStorage("focusTimer.accentColorID") private var accentColorID = FocusTimerTheme.tomato.rawValue
    @AppStorage("focusTimer.customAccentColorHex") private var customAccentColorHex = ""
    @AppStorage("focusTimer.appearanceModeID") private var appearanceModeID = FocusTimerAppearanceMode.system.rawValue
    @AppStorage("focusTimer.menuBarIconEnabled") private var menuBarIconEnabled = true
    @AppStorage("focusTimer.menuBarIconStyleID") private var menuBarIconStyleID = FocusTimerMenuBarIconStyle.normal.rawValue
    @AppStorage("focusTimer.floatingTimerOpacity") private var floatingTimerOpacity = 0.92
    @AppStorage("focusTimer.floatingTimerClickThrough") private var floatingTimerClickThrough = false

    init() {
        FocusTimerPreferenceMigration.migrateLegacyKeys()

        let timerStore = TimerStore()
        _store = StateObject(wrappedValue: timerStore)
        _clock = StateObject(wrappedValue: FocusTimerClock(initialSeconds: timerStore.lastUsedDurationSeconds))
    }

    private var accentColor: Color {
        FocusTimerAccentColor.color(selectionID: accentColorID, customHex: customAccentColorHex)
    }

    private var appearanceMode: FocusTimerAppearanceMode {
        FocusTimerAppearanceMode.resolved(from: appearanceModeID)
    }

    private var preferredColorScheme: ColorScheme {
        appearanceMode.resolvedColorScheme(systemColorScheme: systemAppearance.colorScheme)
    }

    var body: some Scene {
        Window("Focus Timer", id: MainWindowScene.id) {
            ContentView(
                clock: clock,
                store: store,
                windowCommandCenter: windowCommandCenter
            )
                .preferredColorScheme(preferredColorScheme)
        }
        .defaultSize(width: MainWindowScene.width, height: MainWindowScene.height)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Floating Timer", id: FloatingTimerWindowScene.id) {
            FloatingTimerView(
                clock: clock,
                store: store,
                windowCommandCenter: windowCommandCenter,
                accentColor: accentColor,
                windowOpacity: floatingTimerOpacity,
                clickThroughEnabled: floatingTimerClickThrough,
                appearanceModeID: appearanceModeID,
                menuBarIconEnabled: menuBarIconEnabled,
                menuBarIconStyleID: menuBarIconStyleID
            )
            .preferredColorScheme(preferredColorScheme)
        }
        .defaultSize(width: FloatingTimerWindowScene.width, height: FloatingTimerWindowScene.height)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
