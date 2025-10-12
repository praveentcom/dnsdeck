

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
                .frame(minWidth: Constants.UI.minimumWindowWidth, minHeight: Constants.UI.minimumWindowHeight)
        }
        .commands { SidebarCommands() }

        Settings {
            PreferencesView()
                .environmentObject(model)
                .frame(minWidth: Constants.UI.preferencesWindowWidth, maxWidth: Constants.UI.preferencesWindowWidth, minHeight: Constants.UI.preferencesWindowHeight)
        }
    }
}
