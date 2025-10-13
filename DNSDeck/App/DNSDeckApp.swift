

import SwiftUI

@main
struct DNSDeckApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onAppear {
                    Task { await model.refreshZones() }
                }
            #if os(macOS)
                .frame(minWidth: Constants.UI.minimumWindowWidth, minHeight: Constants.UI.minimumWindowHeight)
            #endif
        }
        #if os(macOS)
        .commands { SidebarCommands() }
        #endif

        #if os(macOS)
        Settings {
            PreferencesView()
                .environmentObject(model)
                .frame(
                    minWidth: Constants.UI.preferencesWindowWidth,
                    maxWidth: Constants.UI.preferencesWindowWidth,
                    minHeight: Constants.UI.preferencesWindowHeight
                )
        }
        #endif
    }
}
