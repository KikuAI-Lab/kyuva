import SwiftUI

struct MobilePromptSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fontSize") private var fontSize = 34.0
    @AppStorage("mirrorText") private var mirrorText = false
    @AppStorage("stageDirectionStyle") private var stageDirectionStyle = 1
    @AppStorage(ScrollController.paceModeDefaultsKey) private var paceMode = ScrollPaceMode.fixedSpeed.rawValue
    @AppStorage(ScrollController.speedDefaultsKey) private var fixedSpeed = 50.0
    @AppStorage(ScrollController.wordsPerMinuteDefaultsKey) private var wordsPerMinute = 150.0
    @AppStorage(ScrollController.targetDurationDefaultsKey) private var targetDuration = 300.0

    var body: some View {
        Form {
            Section("Reading") {
                LabeledContent("Text size", value: "\(Int(fontSize)) pt")
                Slider(value: $fontSize, in: 22...72, step: 1)
                    .accessibilityLabel("Text size")

                Toggle("Mirror for teleprompter glass", isOn: $mirrorText)

                Picker("Stage directions", selection: $stageDirectionStyle) {
                    Text("Normal").tag(0)
                    Text("Dimmed").tag(1)
                    Text("Hidden").tag(2)
                }
            }

            Section("Pace") {
                Picker("Mode", selection: $paceMode) {
                    Text("Fixed").tag(ScrollPaceMode.fixedSpeed.rawValue)
                    Text("Words/min").tag(ScrollPaceMode.wordsPerMinute.rawValue)
                    Text("Finish time").tag(ScrollPaceMode.targetDuration.rawValue)
                }
                .pickerStyle(.segmented)

                switch ScrollPaceMode(rawValue: paceMode) ?? .fixedSpeed {
                case .fixedSpeed:
                    LabeledContent("Speed", value: "\(Int(fixedSpeed))")
                    Slider(value: $fixedSpeed, in: 10...200, step: 5)
                case .wordsPerMinute:
                    LabeledContent("Words per minute", value: "\(Int(wordsPerMinute))")
                    Slider(value: $wordsPerMinute, in: 60...240, step: 5)
                case .targetDuration:
                    LabeledContent("Finish in", value: durationLabel)
                    Slider(value: $targetDuration, in: 30...3_600, step: 30)
                }
            }

            Section {
                Text("Scripts and settings stay on this device. Kyuva has no account, analytics, ads, or required cloud service.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Prompt Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var durationLabel: String {
        let seconds = Int(targetDuration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
