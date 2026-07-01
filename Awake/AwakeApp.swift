import SwiftUI

@main
struct AwakeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            AppMenu()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.caffeineActive ? "cup.and.saucer.fill" : "cup.and.saucer")
        }
        .menuBarExtraStyle(.menu)

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 440, height: 720)
        .defaultPosition(.center)
    }
}
