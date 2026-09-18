import SwiftUI

@main
struct AwakeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            AppMenu()
                .environmentObject(appState)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: appState.caffeineActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                if appState.isDimmed {
                    Image(systemName: "moon.fill")
                }
            }
        }
        .menuBarExtraStyle(.menu)

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 440, height: 800)
        .defaultPosition(.center)
    }
}
