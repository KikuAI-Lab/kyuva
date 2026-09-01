import SwiftUI

struct MobilePromptSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var proStore = ProEntitlementStore.shared
    @AppStorage("fontSize") private var fontSize = 34.0
    @AppStorage("textAlignment") private var textAlignment = 1
    @AppStorage("fontFamily") private var fontFamily = 0
    @AppStorage("mirrorText") private var mirrorText = false
    @AppStorage("stageDirectionStyle") private var stageDirectionStyle = 1
    @AppStorage(ScrollController.paceModeDefaultsKey) private var paceMode = ScrollPaceMode.fixedSpeed.rawValue
    @AppStorage(ScrollController.speedDefaultsKey) private var fixedSpeed = 50.0
    @AppStorage(ScrollController.wordsPerMinuteDefaultsKey) private var wordsPerMinute = 150.0
    @AppStorage(ScrollController.targetDurationDefaultsKey) private var targetDuration = 300.0
    @State private var proMessage: String?

    var body: some View {
        Form {
            Section("Reading") {
                LabeledContent("Text size", value: "\(Int(fontSize)) pt")
                Slider(value: $fontSize, in: 22...72, step: 1)
                    .accessibilityLabel("Text size")
                    .accessibilityValue("\(Int(fontSize)) points")

                Picker("Typeface", selection: $fontFamily) {
                    Text("System").tag(0)
                    Text("Monospaced").tag(1)
                    Text("Serif").tag(2)
                    Text("Rounded").tag(3)
                }
                .pickerStyle(.navigationLink)

                Picker("Alignment", selection: $textAlignment) {
                    Text("Leading").tag(0)
                    Text("Center").tag(1)
                    Text("Trailing").tag(2)
                }
                .pickerStyle(.navigationLink)

                Toggle("Mirror for teleprompter glass", isOn: $mirrorText)

                Picker("Stage directions", selection: $stageDirectionStyle) {
                    Text("Normal").tag(0)
                    Text("Dimmed").tag(1)
                    Text("Hidden").tag(2)
                }
            }

            Section("Pace") {
                Picker("Pace mode", selection: $paceMode) {
                    Text("Fixed").tag(ScrollPaceMode.fixedSpeed.rawValue)
                    Text("Words/min").tag(ScrollPaceMode.wordsPerMinute.rawValue)
                    Text("Finish time").tag(ScrollPaceMode.targetDuration.rawValue)
                }
                .pickerStyle(.navigationLink)

                switch ScrollPaceMode(rawValue: paceMode) ?? .fixedSpeed {
                case .fixedSpeed:
                    LabeledContent("Speed", value: "\(Int(fixedSpeed))")
                    Slider(value: $fixedSpeed, in: 10...200, step: 5)
                        .accessibilityLabel("Scroll speed")
                        .accessibilityValue("\(Int(fixedSpeed)) pixels per second")
                case .wordsPerMinute:
                    LabeledContent("Words per minute", value: "\(Int(wordsPerMinute))")
                    Slider(value: $wordsPerMinute, in: 60...240, step: 5)
                        .accessibilityLabel("Reading pace")
                        .accessibilityValue("\(Int(wordsPerMinute)) words per minute")
                case .targetDuration:
                    LabeledContent("Finish in", value: durationLabel)
                    Slider(value: $targetDuration, in: 30...3_600, step: 30)
                        .accessibilityLabel("Finish time")
                        .accessibilityValue(durationLabel)
                }
            }

            Section(ProEntitlementStore.commerceEnabled ? "Kyuva Pro" : "Voice Follow") {
                Label(proAccessLabel, systemImage: "sparkles")

                Text(proDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if ProEntitlementStore.commerceEnabled {
                    if proStore.accessState == .locked {
                        Button("Start 7-Day Trial") {
                            proStore.startTrial()
                        }
                    }

                    if proStore.accessState != .purchased {
                        Button(proPurchaseLabel) {
                            Task {
                                proMessage = message(for: await proStore.purchaseLifetime())
                            }
                        }
                        .disabled(
                            proStore.lifetimeProduct == nil ||
                            proStore.isLoading ||
                            proStore.isProcessingTransaction
                        )
                    }

                    Button("Restore Purchase") {
                        Task {
                            proMessage = await proStore.restorePurchases()
                                ? "Your lifetime purchase was restored."
                                : "No verified lifetime purchase was found."
                        }
                    }
                    .disabled(proStore.isLoading || proStore.isProcessingTransaction)
                } else {
                    Text("Open preview · no purchase available")
                        .foregroundStyle(.secondary)
                }

                if let proMessage {
                    Text(proMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Scripts and settings stay on this device. Kyuva has no account, analytics, ads, or required cloud service.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Kyuva") {
                Link(
                    "Website",
                    destination: URL(string: "https://kiku-jw.github.io/kyuva-landing/")!
                )
                Link("Rate Kyuva", destination: ReviewPromptPolicy.appStoreReviewURL)
                Link(
                    "Send Feedback",
                    destination: URL(string: "mailto:support@kikuai.dev")!
                )
            }
        }
        .navigationTitle("Prompt Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            await proStore.prepare()
        }
    }

    private var durationLabel: String {
        let seconds = Int(targetDuration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var proAccessLabel: String {
        switch proStore.accessState {
        case .openPreview:
            return "Voice Follow Preview"
        case .purchased:
            return "Lifetime Pro Unlocked"
        case .trial(let daysRemaining):
            return "Pro Trial · \(daysRemaining) Days Left"
        case .locked:
            return "Kyuva Pro"
        }
    }

    private var proPurchaseLabel: String {
        if let displayPrice = proStore.displayPrice {
            return "Unlock Forever · \(displayPrice)"
        }
        return "Unlock Forever"
    }

    private var proDescription: String {
        if ProEntitlementStore.commerceEnabled {
            return "Voice Follow is the first Pro feature. Buy once to unlock it on Mac and iPhone, or try it free for seven days."
        }
        return "On-device Voice Follow remains available to everyone while commerce is inactive."
    }

    private func message(for outcome: ProPurchaseOutcome) -> String {
        switch outcome {
        case .purchased:
            return "Lifetime Pro is unlocked."
        case .pending:
            return "The purchase is pending Apple approval."
        case .cancelled:
            return "Purchase cancelled."
        case .unavailable:
            return "The lifetime product is not available."
        case .failed:
            return "Apple could not complete the purchase."
        }
    }
}
