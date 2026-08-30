import AppKit
import SwiftUI

private let studioAccent = Color(red: 0.79, green: 0.81, blue: 1.0)

private enum StudioInspectorPane: String, CaseIterable, Identifiable {
    case prompt = "Prompt"
    case shortcuts = "Shortcuts"
    case about = "About"

    var id: String { rawValue }
}

struct SettingsView: View {
    @StateObject private var scriptManager = ScriptManager.shared
    @ObservedObject private var proStore = ProEntitlementStore.shared

    @State private var searchText = ""
    @State private var inspectorPane = StudioInspectorPane.prompt
    @State private var showDeleteConfirmation = false
    @State private var scriptToDelete: UUID?
    @State private var proMessage: String?

    @AppStorage("overlayOpacity") private var opacity = 0.85
    @AppStorage("fontSize") private var fontSize = 18.0
    @AppStorage("scrollSpeed") private var scrollSpeed = 50.0
    @AppStorage("overlayWidth") private var overlayWidth = 350.0
    @AppStorage("overlayHeight") private var overlayHeight = 150.0
    @AppStorage("textAlignment") private var textAlignment = 1
    @AppStorage("fontFamily") private var fontFamily = 0
    @AppStorage("mirrorText") private var mirrorText = false
    @AppStorage("stageDirectionStyle") private var stageDirectionStyle = 1
    @AppStorage(ScrollController.paceModeDefaultsKey) private var scrollPaceMode = ScrollPaceMode.fixedSpeed.rawValue
    @AppStorage(ScrollController.wordsPerMinuteDefaultsKey) private var wordsPerMinute = 150.0
    @AppStorage(ScrollController.targetDurationDefaultsKey) private var targetDurationSeconds = 300.0
    @AppStorage("focusModeIntensity") private var focusModeIntensity = 0
    @AppStorage("endBehavior") private var endBehavior = 0

    private var selectedIndex: Int? {
        guard let selectedId = scriptManager.selectedScriptId else { return nil }
        return scriptManager.scripts.firstIndex { $0.id == selectedId }
    }

    private var filteredScripts: [Script] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return scriptManager.scripts }
        return scriptManager.scripts.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.content.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationSplitView {
            scriptLibrary
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            HSplitView {
                editor
                    .frame(minWidth: 430, maxWidth: .infinity, maxHeight: .infinity)

                inspector
                    .frame(minWidth: 280, idealWidth: 300, maxWidth: 340, maxHeight: .infinity)
            }
        }
        .navigationTitle("Kyuva")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    scriptManager.importScript()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                Button {
                    showPrompt()
                } label: {
                    Label("Open Prompt", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(studioAccent)
                .foregroundStyle(.black)
                .disabled(scriptManager.selectedScript?.lines.isEmpty != false)
            }
        }
        .tint(studioAccent)
        .frame(minWidth: 920, minHeight: 580)
        .task {
            await proStore.prepare()
        }
        .alert("Delete this script?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                scriptToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deletePendingScript()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var scriptLibrary: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scripts")
                        .font(.title2.bold())
                    Text("Stored only on this Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    scriptManager.createNewScript()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .help("New script")
                .accessibilityLabel("New script")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            List(selection: $scriptManager.selectedScriptId) {
                ForEach(filteredScripts) { script in
                    ScriptLibraryRow(script: script)
                        .tag(script.id)
                        .contextMenu {
                            Button("Export") {
                                scriptManager.exportScript(script)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                requestDelete(script.id)
                            }
                            .disabled(scriptManager.scripts.count <= 1)
                        }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search scripts")

            if filteredScripts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No matching scripts")
                        .font(.headline)
                    Text("Try another search or create a new script.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var editor: some View {
        if let index = selectedIndex {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    TextField(
                        "Script title",
                        text: nameBinding(for: scriptManager.scripts[index].id)
                    )
                        .textFieldStyle(.plain)
                        .font(.title2.weight(.semibold))
                        .accessibilityLabel("Script title")

                    Button {
                        scriptManager.exportScript(scriptManager.scripts[index])
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Export script")
                    .accessibilityLabel("Export script")

                    Button {
                        requestDelete(scriptManager.scripts[index].id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Delete script")
                    .accessibilityLabel("Delete script")
                    .disabled(scriptManager.scripts.count <= 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 10)

                HStack(spacing: 16) {
                    Label(
                        "\(scriptManager.scripts[index].wordCount(excludingStageDirections: false)) words",
                        systemImage: "text.word.spacing"
                    )
                    Label(
                        estimatedDuration(for: scriptManager.scripts[index]),
                        systemImage: "clock"
                    )
                    Spacer()
                    Label("Autosaved locally", systemImage: "checkmark.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

                Divider()

                TextEditor(text: contentBinding(for: scriptManager.scripts[index].id))
                    .font(.system(size: 16, design: .default))
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Color(nsColor: .textBackgroundColor))
                    .accessibilityLabel("Script text")

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "text.badge.checkmark")
                        .foregroundStyle(.secondary)
                    Text("Put stage directions on their own line inside [square] or (round) brackets.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Prompt") {
                        showPrompt()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(studioAccent)
                    .foregroundStyle(.black)
                    .disabled(scriptManager.scripts[index].lines.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Choose a script")
                    .font(.title2.bold())
                Text("Select a script from the library or create a new one.")
                    .foregroundStyle(.secondary)
                Button("New Script") {
                    scriptManager.createNewScript()
                }
                .buttonStyle(.borderedProminent)
                .tint(studioAccent)
                .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var inspector: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $inspectorPane) {
                ForEach(StudioInspectorPane.allCases) { pane in
                    Text(pane.rawValue).tag(pane)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(16)

            Divider()

            ScrollView {
                Group {
                    switch inspectorPane {
                    case .prompt:
                        promptInspector
                    case .shortcuts:
                        shortcutsInspector
                    case .about:
                        aboutInspector
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var promptInspector: some View {
        VStack(alignment: .leading, spacing: 20) {
            inspectorHeader("Pace", detail: "Choose how the prompt advances.")

            Picker("Pace mode", selection: $scrollPaceMode) {
                ForEach(ScrollPaceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            paceControl

            Divider()

            inspectorHeader("Reading", detail: "Tune the words, not the interface.")

            valueSlider(
                title: "Text size",
                value: $fontSize,
                range: 12...36,
                step: 1,
                valueLabel: "\(Int(fontSize)) pt"
            )

            Picker("Typeface", selection: $fontFamily) {
                Text("System").tag(0)
                Text("Monospaced").tag(1)
                Text("Serif").tag(2)
                Text("Rounded").tag(3)
            }

            Picker("Alignment", selection: $textAlignment) {
                Text("Left").tag(0)
                Text("Center").tag(1)
                Text("Right").tag(2)
            }
            .pickerStyle(.segmented)

            Picker("Stage directions", selection: $stageDirectionStyle) {
                Text("Show").tag(0)
                Text("Dim").tag(1)
                Text("Hide").tag(2)
            }
            .pickerStyle(.segmented)

            Toggle("Mirror text for teleprompter glass", isOn: $mirrorText)

            Divider()

            DisclosureGroup("Overlay layout") {
                VStack(alignment: .leading, spacing: 14) {
                    valueSlider(
                        title: "Width",
                        value: $overlayWidth,
                        range: 200...600,
                        step: 10,
                        valueLabel: "\(Int(overlayWidth)) px"
                    )
                    valueSlider(
                        title: "Height",
                        value: $overlayHeight,
                        range: 80...400,
                        step: 10,
                        valueLabel: "\(Int(overlayHeight)) px"
                    )
                    valueSlider(
                        title: "Opacity",
                        value: $opacity,
                        range: 0.3...1,
                        step: 0.05,
                        valueLabel: "\(Int(opacity * 100))%"
                    )

                    Picker("Focus", selection: $focusModeIntensity) {
                        Text("Off").tag(0)
                        Text("Soft").tag(1)
                        Text("Medium").tag(2)
                        Text("Strong").tag(3)
                    }

                    Picker("At the end", selection: $endBehavior) {
                        Text("Stay at end").tag(0)
                        Text("Start over").tag(1)
                        Text("Next script").tag(2)
                    }
                }
                .padding(.top, 12)
            }

            Button {
                showPrompt()
            } label: {
                Label("Open Camera-Side Prompt", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(studioAccent)
            .foregroundStyle(.black)
            .disabled(scriptManager.selectedScript?.lines.isEmpty != false)
        }
    }

    @ViewBuilder
    private var paceControl: some View {
        switch ScrollPaceMode(rawValue: scrollPaceMode) ?? .fixedSpeed {
        case .fixedSpeed:
            valueSlider(
                title: "Scroll speed",
                value: $scrollSpeed,
                range: ScrollController.minimumSpeed...ScrollController.maximumSpeed,
                step: 5,
                valueLabel: "\(Int(scrollSpeed))"
            )
        case .wordsPerMinute:
            valueSlider(
                title: "Reading pace",
                value: $wordsPerMinute,
                range: ScrollController.minimumWordsPerMinute...ScrollController.maximumWordsPerMinute,
                step: 5,
                valueLabel: "\(Int(wordsPerMinute)) WPM"
            )
        case .targetDuration:
            valueSlider(
                title: "Finish in",
                value: $targetDurationSeconds,
                range: ScrollController.minimumTargetDuration...ScrollController.maximumTargetDuration,
                step: 30,
                valueLabel: durationText(targetDurationSeconds)
            )
        }
    }

    private var shortcutsInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            inspectorHeader(
                "Global shortcuts",
                detail: "Fixed shortcuts work without keyboard-monitoring permission."
            )

            shortcutRow("Play or pause", HotkeyManager.Hotkey.togglePause.shortcut.display)
            shortcutRow("Faster", HotkeyManager.Hotkey.speedUp.shortcut.display)
            shortcutRow("Slower", HotkeyManager.Hotkey.speedDown.shortcut.display)
            shortcutRow("Voice Follow", HotkeyManager.Hotkey.toggleVoiceFollow.shortcut.display)
            shortcutRow("Start over", HotkeyManager.Hotkey.reset.shortcut.display)
            shortcutRow("Show or hide prompt", HotkeyManager.Hotkey.toggleOverlay.shortcut.display)
            shortcutRow("Next display", HotkeyManager.Hotkey.nextDisplay.shortcut.display)
        }
    }

    private var aboutInspector: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Kyuva")
                        .font(.title2.bold())
                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Private prompting across your Apple devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Label("Your scripts stay on this device.", systemImage: "lock.shield")
                .font(.headline)

            Text("Kyuva has no account, analytics, ads, or required cloud service. The prompt may appear in screen shares or recordings, so verify your preview before presenting.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label(proAccessLabel, systemImage: "waveform")
                .font(.headline)

            Text(proDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            if ProEntitlementStore.commerceEnabled {
                proControls
            } else {
                Text("Open preview · no purchase available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let proMessage {
                Text(proMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Show Welcome Guide") {
                NotificationCenter.default.post(name: .showOnboarding, object: nil)
            }

            Link("Website", destination: URL(string: "https://kiku-jw.github.io/kyuva-landing/")!)
            Link("Rate Kyuva", destination: ReviewPromptPolicy.appStoreReviewURL)

            Button("Send Feedback") {
                if let url = URL(string: "mailto:support@kikuai.dev") {
                    NSWorkspace.shared.open(url)
                }
            }

            Text(copyrightText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var proControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if proStore.accessState == .locked {
                Button("Start 7-Day Trial") {
                    proStore.startTrial()
                }
            }

            if proStore.accessState != .purchased {
                Button(proPurchaseLabel) {
                    guard let confirmationWindow = NSApp.keyWindow else {
                        proMessage = "Kyuva could not open the purchase confirmation."
                        return
                    }
                    Task {
                        proMessage = message(
                            for: await proStore.purchaseLifetime(confirmIn: confirmationWindow)
                        )
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
        }
    }

    private func inspectorHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(valueLabel)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(valueLabel)
        }
    }

    private func shortcutRow(_ title: String, _ shortcut: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortcut)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private func nameBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { scriptManager.scripts.first(where: { $0.id == id })?.name ?? "" },
            set: { scriptManager.updateScriptName(id, name: $0) }
        )
    }

    private func contentBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { scriptManager.scripts.first(where: { $0.id == id })?.content ?? "" },
            set: { scriptManager.updateScriptContent(id, content: $0) }
        )
    }

    private func estimatedDuration(for script: Script) -> String {
        let words = script.wordCount(excludingStageDirections: stageDirectionStyle != 0)
        let pace = max(1, wordsPerMinute)
        let seconds = max(1, Int((Double(words) / pace * 60).rounded()))
        return "About \(durationText(Double(seconds)))"
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        if totalSeconds >= 3_600 {
            return String(
                format: "%d:%02d:%02d",
                totalSeconds / 3_600,
                (totalSeconds % 3_600) / 60,
                totalSeconds % 60
            )
        }
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func showPrompt() {
        scriptManager.flushPendingSave()
        NotificationCenter.default.post(name: .showOverlay, object: nil)
    }

    private func requestDelete(_ id: UUID) {
        scriptToDelete = id
        showDeleteConfirmation = true
    }

    private func deletePendingScript() {
        guard scriptManager.scripts.count > 1,
              let id = scriptToDelete,
              let index = scriptManager.scripts.firstIndex(where: { $0.id == id }) else {
            scriptToDelete = nil
            return
        }
        scriptManager.deleteScripts(at: IndexSet(integer: index))
        scriptToDelete = nil
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "Version \(version) (\(build))"
        }
        return "Version \(version)"
    }

    private var copyrightText: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
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

private struct ScriptLibraryRow: View {
    let script: Script

    private var preview: String {
        script.lines.first ?? "Empty script"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(script.name)
                .font(.headline)
                .lineLimit(1)

            Text(preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text("\(script.wordCount(excludingStageDirections: false)) words")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}
