

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
                .frame(minWidth: 800, minHeight: 800)
        }
        .commands { SidebarCommands() }

        Settings {
            PreferencesView()
                .environmentObject(model)
                .frame(minWidth: 640, maxWidth: 640, minHeight: 480)
        }
    }
}
