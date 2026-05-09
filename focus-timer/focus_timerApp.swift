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
    @AppStorage("focusTimer.miniWindowOpacity") private var miniWindowOpacity = 0.92
    @AppStorage("focusTimer.miniWindowClickThrough") private var miniWindowClickThrough = false

    private var theme: FocusTimerTheme {
        FocusTimerTheme(rawValue: accentColorID) ?? .tomato
    }

    var body: some Scene {
        WindowGroup {
            ContentView(clock: clock, store: store)
        }
        .defaultSize(width: 340, height: 530)
        .windowResizability(.contentSize)

        Window("Mini Timer", id: MiniTimerWindowScene.id) {
            MiniTimerView(
                clock: clock,
                accentColor: theme.color,
                windowOpacity: miniWindowOpacity,
                clickThroughEnabled: miniWindowClickThrough
            )
        }
        .defaultSize(width: MiniTimerWindowScene.width, height: MiniTimerWindowScene.height)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
