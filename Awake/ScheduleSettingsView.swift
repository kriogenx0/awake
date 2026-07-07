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

                    LabeledContent("Preview") {
                        Button {
                            if isPreviewingDim { state.stopPreviewDim() } else { state.previewDim() }
                            isPreviewingDim.toggle()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(LinearGradient(
                                        colors: [Color(red: 0.25, green: 0.45, blue: 0.72),
                                                 Color(red: 0.12, green: 0.22, blue: 0.48)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.18))
                                        .frame(height: 9)
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 80, height: 10)
                                        .padding(.bottom, 4)
                                }
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(state.dimOpacity))
                                    .animation(.easeInOut(duration: 0.15), value: state.dimOpacity)
                                Text(isPreviewingDim ? "Click to hide" : "Click to preview")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(width: 213, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isPreviewingDim ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: isPreviewingDim ? 2 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
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
