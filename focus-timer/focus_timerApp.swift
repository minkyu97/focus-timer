//
//  focus_timerApp.swift
//  focus-timer
//
//  Created by minkyu on 5/8/26.
//

import SwiftUI

@main
struct focus_timerApp: App {
    @StateObject private var clock = FocusTimerClock()
    @StateObject private var store = TimerStore()

    @AppStorage("focusTimer.accentColorID") private var accentColorID = FocusTimerTheme.tomato.rawValue
    @AppStorage("focusTimer.customAccentColorHex") private var customAccentColorHex = ""
    @AppStorage("focusTimer.miniWindowOpacity") private var miniWindowOpacity = 0.92
    @AppStorage("focusTimer.miniWindowClickThrough") private var miniWindowClickThrough = false

    private var accentColor: Color {
        FocusTimerAccentColor.color(selectionID: accentColorID, customHex: customAccentColorHex)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(clock: clock, store: store)
        }
        .defaultSize(width: MainWindowScene.width, height: MainWindowScene.height)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Mini Timer", id: MiniTimerWindowScene.id) {
            MiniTimerView(
                clock: clock,
                accentColor: accentColor,
                windowOpacity: miniWindowOpacity,
                clickThroughEnabled: miniWindowClickThrough
            )
        }
        .defaultSize(width: MiniTimerWindowScene.width, height: MiniTimerWindowScene.height)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
