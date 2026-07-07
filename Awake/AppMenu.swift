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

        Menu("When Inactive") {
            Text("For...")
            ForEach(DisplayDimDelay.allCases, id: \.rawValue) { delay in
                Button {
                    state.displayDimDelay = delay
                } label: {
                    HStack {
                        Text(delay.label)
                        if state.displayDimDelay == delay {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Text("...Then")
            Button {} label: {
                HStack {
                    Text("Dim display")
                    Image(systemName: "checkmark")
                }
            }
            .disabled(true)
        }

        Divider()

        Toggle("Stay Awake on Schedule", isOn: Binding(
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
