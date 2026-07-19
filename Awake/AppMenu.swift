import SwiftUI

struct AppMenu: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) var openWindow

    var body: some View {
        Text(state.statusText)

        Divider()

        Menu("Stay Awake") {
            Toggle("Off", isOn: Binding(
                get: { !state.caffeineActive },
                set: { _ in state.turnOff() }
            ))

            Toggle("Indefinitely", isOn: Binding(
                get: { state.caffeineActive && state.activeDuration == nil },
                set: { _ in state.enableCaffeineIndefinitely() }
            ))

            Divider()

            ForEach(StayAwakeDuration.allCases, id: \.rawValue) { duration in
                Toggle("For \(duration.label)", isOn: Binding(
                    get: { state.activeDuration == duration },
                    set: { _ in state.enableCaffeine(for: duration) }
                ))
            }
        }

        if let remaining = state.awakeRemainingText {
            Text(remaining)
                .foregroundStyle(.secondary)
        }

        Menu("Dim Display After") {
            ForEach(DisplayDimDelay.allCases, id: \.rawValue) { option in
                Toggle(option.label, isOn: Binding(
                    get: { state.displayDimDelay == option },
                    set: { _ in state.displayDimDelay = option }
                ))
            }
        }

        if state.displayDimDelay != .never {
            Menu("Black Display After") {
                ForEach(DisplayBlackDelay.allCases, id: \.rawValue) { option in
                    Toggle(option.label, isOn: Binding(
                        get: { state.displayBlackDelay == option },
                        set: { _ in state.displayBlackDelay = option }
                    ))
                }
            }
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
