import SwiftUI

struct AppMenu: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) var openWindow

    var body: some View {
        Text(state.statusText)

        Divider()

        Toggle("Stay Awake", isOn: Binding(
            get: { state.caffeineActive },
            set: { _ in state.toggleManual() }
        ))

        Picker("When Inactive For", selection: $state.displayDimDelay) {
            ForEach(DisplayDimDelay.allCases, id: \.rawValue) {
                Text($0.label).tag($0)
            }
        }

        Picker("…Then", selection: $state.displayInactiveAction) {
            ForEach(DisplayInactiveAction.allCases, id: \.rawValue) {
                Text($0.label).tag($0)
            }
        }
        .disabled(state.displayDimDelay == .never)

        Divider()

        Toggle("Schedule", isOn: Binding(
            get: { state.scheduleEnabled },
            set: { state.setScheduleEnabled($0) }
        ))

        Button("Settings…") {
            openWindow(id: "settings")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Quit Awake") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
