import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var isPreviewingDim = false

    private let orderedDays: [(Int, String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"),
        (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Awake")
                            .font(.title2.bold())
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("General") {
                Toggle("Launch at login", isOn: $state.launchAtLogin)
                Toggle("Move mouse to stay awake", isOn: $state.jiggleMouse)
            }

            Section("Display") {
                Toggle("Allow display sleep without lock", isOn: $state.preventScreenLock)

                LabeledContent("When Inactive") {
                    HStack(spacing: 6) {
                        Text("For...")
                            .foregroundStyle(.secondary)
                        Picker("duration", selection: $state.displayDimDelay) {
                            ForEach(DisplayDimDelay.allCases, id: \.rawValue) {
                                Text($0.label).tag($0)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }

                if state.displayDimDelay != .never {
                    LabeledContent("Overlay Darkness") {
                        HStack {
                            Slider(value: $state.dimOpacity, in: 0.1...0.95)
                                .frame(width: 160)
                            Text("\(Int(state.dimOpacity * 100))%")
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }

                if state.displayInactiveAction == .dim {
                    LabeledContent("Dim amount") {
                        Slider(value: $state.dimOpacity, in: 0.1...1.0)
                            .frame(width: 160)
                    }

                    LabeledContent("Preview") {
                        Button {
                            if isPreviewingDim {
                                state.stopPreviewDim()
                            } else {
                                state.previewDim()
                            }
                            isPreviewingDim.toggle()
                        } label: {
                            Text(isPreviewingDim ? "Stop Preview" : "Preview")
                        }
                    }
                }
            }

            Section("Schedule — Days") {
                HStack(spacing: 4) {
                    ForEach(orderedDays, id: \.0) { weekday, name in
                        Toggle(name, isOn: Binding(
                            get: { state.activeDays.contains(weekday) },
                            set: { _ in state.toggleDay(weekday) }
                        ))
                        .toggleStyle(.button)
                    }
                }
                .padding(.vertical, 2)
            }

            Section("Schedule — Hours") {
                LabeledContent("From") {
                    Picker("From", selection: $state.startHour) {
                        ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 110)
                }

                LabeledContent("To") {
                    Picker("To", selection: $state.endHour) {
                        ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 110)
                }

                if state.endHour <= state.startHour {
                    Text("End time must be after start time.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 780)
        .onDisappear {
            if isPreviewingDim {
                state.stopPreviewDim()
                isPreviewingDim = false
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        var c = DateComponents()
        c.hour = hour
        c.minute = 0
        guard let date = Calendar.current.date(from: c) else { return "\(hour):00" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}
