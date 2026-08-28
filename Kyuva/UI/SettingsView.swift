import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("overlayOpacity") private var opacity: Double = 0.85
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("scrollSpeed") private var scrollSpeed: Double = 50
    
    // Appearance
    @AppStorage("overlayWidth") private var overlayWidth: Double = 350
    @AppStorage("overlayHeight") private var overlayHeight: Double = 150
    @AppStorage("textAlignment") private var textAlignment: Int = 1 // 0=Left, 1=Center, 2=Right
    @AppStorage("fontFamily") private var fontFamily: Int = 0 // 0=System, 1=Mono, 2=Serif, 3=Rounded
    @AppStorage("mirrorText") private var mirrorText = false
    @AppStorage("stageDirectionStyle") private var stageDirectionStyle = 1

    // Pace
    @AppStorage(ScrollController.paceModeDefaultsKey) private var scrollPaceMode = ScrollPaceMode.fixedSpeed.rawValue
    @AppStorage(ScrollController.wordsPerMinuteDefaultsKey) private var wordsPerMinute: Double = 150
    @AppStorage(ScrollController.targetDurationDefaultsKey) private var targetDurationSeconds: Double = 300
    
    // Focus Mode
    @AppStorage("focusModeIntensity") private var focusModeIntensity: Int = 0 // 0=Off, 1=Subtle, 2=Medium, 3=Strong
    
    // Behavior
    @AppStorage("endBehavior") private var endBehavior: Int = 0 // 0=Do Nothing, 1=Start Over, 2=Play Next
    
    @StateObject private var scriptManager = ScriptManager.shared
    @ObservedObject private var proStore = ProEntitlementStore.shared
    @State private var proMessage: String?
    
    var body: some View {
        TabView {
            // Script Tab
            scriptTab
                .tabItem {
                    Label("Script", systemImage: "doc.text")
                }
            
            // Appearance Tab
            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            // Scroll Tab
            scrollTab
                .tabItem {
                    Label("Scroll", systemImage: "scroll")
                }
            
            // Hotkeys Tab
            hotkeysTab
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }

            // About Tab
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
            
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await proStore.prepare()
        }
    }
    
    // MARK: - Script Tab
    
    @State private var showDeleteConfirm = false
    @State private var scriptToDelete: UUID?
    
    private var scriptTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with actions
            HStack {
                Text("Scripts")
                    .font(.headline)
                Spacer()
                
                if scriptManager.selectedScriptId != nil {
                    Button(action: {
                        scriptToDelete = scriptManager.selectedScriptId
                        showDeleteConfirm = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete selected script")
                    .accessibilityLabel("Delete selected script")
                }
                
                Button(action: { scriptManager.createNewScript() }) {
                    Image(systemName: "plus")
                }
                .help("New script")
                .accessibilityLabel("New script")
                
                Button(action: { scriptManager.importScript() }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Import from file")
                .accessibilityLabel("Import from file")
                
                if let script = scriptManager.selectedScript {
                    Button(action: { scriptManager.exportScript(script) }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export to file")
                    .accessibilityLabel("Export selected script")
                }
            }
            
            // Script list
            List(selection: $scriptManager.selectedScriptId) {
                ForEach(scriptManager.scripts) { script in
                    HStack {
                        Text(script.name)
                        Spacer()
                        Text("\(script.wordCount(excludingStageDirections: false)) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(script.id)
                    .contextMenu {
                        Button("Export") { scriptManager.exportScript(script) }
                        Divider()
                        Button("Delete", role: .destructive) {
                            scriptToDelete = script.id
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .frame(height: 120)
            .cornerRadius(6)
            
            // Script editor
            if let selectedId = scriptManager.selectedScriptId,
               let index = scriptManager.scripts.firstIndex(where: { $0.id == selectedId }) {
                
                // Name field
                TextField("Script Name", text: $scriptManager.scripts[index].name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: scriptManager.scripts[index].name) { _ in
                        scriptManager.debounceSaveFromUI()
                    }
                
                // Stats bar
                HStack(spacing: 16) {
                    let wordCount = scriptManager.scripts[index].wordCount(excludingStageDirections: false)
                    let readingTime = max(1, Int(ceil(Double(wordCount) / 150)))
                    
                    Label("\(wordCount) words", systemImage: "text.word.spacing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("~\(readingTime) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                // Content editor - direct binding, live updates
                TextEditor(text: $scriptManager.scripts[index].content)
                    .font(.system(size: 13, design: .monospaced))
                    .accessibilityLabel("Script text")
                    .frame(minHeight: 120)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: scriptManager.scripts[index].content) { _ in
                        scriptManager.reindexScript(selectedId)
                        scriptManager.debounceSaveFromUI()
                    }
            } else {
                Text("Select or create a script")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .alert("Delete Script?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let id = scriptToDelete,
                   let index = scriptManager.scripts.firstIndex(where: { $0.id == id }) {
                    scriptManager.deleteScripts(at: IndexSet(integer: index))
                }
                scriptToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    // MARK: - Appearance Tab
    
    private var appearanceTab: some View {
        Form {
            Section("Overlay Size") {
                HStack {
                    Text("Width")
                    Slider(value: $overlayWidth, in: 200...600, step: 10)
                        .accessibilityLabel("Overlay width")
                        .accessibilityValue("\(Int(overlayWidth)) pixels")
                    Text("\(Int(overlayWidth))px")
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Height")
                    Slider(value: $overlayHeight, in: 80...400, step: 10)
                        .accessibilityLabel("Overlay height")
                        .accessibilityValue("\(Int(overlayHeight)) pixels")
                    Text("\(Int(overlayHeight))px")
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Opacity")
                    Slider(value: $opacity, in: 0.3...1.0)
                        .accessibilityLabel("Overlay opacity")
                        .accessibilityValue("\(Int(opacity * 100)) percent")
                    Text("\(Int(opacity * 100))%")
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }
            }
            
            Section("Text") {
                Picker("Font", selection: $fontFamily) {
                    Text("System").tag(0)
                    Text("Monospaced").tag(1)
                    Text("Serif").tag(2)
                    Text("Rounded").tag(3)
                }
                
                HStack {
                    Text("Font Size")
                    Slider(value: $fontSize, in: 12...36)
                        .accessibilityLabel("Font size")
                        .accessibilityValue("\(Int(fontSize)) points")
                    Text("\(Int(fontSize)) pt")
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }
                
                Picker("Text Alignment", selection: $textAlignment) {
                    Text("Left").tag(0)
                    Text("Center").tag(1)
                    Text("Right").tag(2)
                }
                .pickerStyle(.segmented)

                Toggle("Mirror text horizontally", isOn: $mirrorText)
                    .help("Use with a physical beam-splitter teleprompter mirror.")

                Picker("Bracketed Directions", selection: $stageDirectionStyle) {
                    Text("Show").tag(0)
                    Text("Dim").tag(1)
                    Text("Hide").tag(2)
                }
                .pickerStyle(.segmented)

                Text("Applies to complete lines wrapped in [square] or (round) brackets.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Focus Mode") {
                Text("Create a focused reading experience by dimming text outside the reading zone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Intensity", selection: $focusModeIntensity) {
                    Text("Off").tag(0)
                    Text("Subtle").tag(1)
                    Text("Medium").tag(2)
                    Text("Strong").tag(3)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
    }
    
    // MARK: - Scroll Tab
    
    private var scrollTab: some View {
        Form {
            Section("Pace") {
                Picker("Mode", selection: $scrollPaceMode) {
                    ForEach(ScrollPaceMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                switch ScrollPaceMode(rawValue: scrollPaceMode) ?? .fixedSpeed {
                case .fixedSpeed:
                    Slider(
                        value: $scrollSpeed,
                        in: ScrollController.minimumSpeed...ScrollController.maximumSpeed
                    ) {
                        Text("Scroll Speed")
                    }
                    Text("\(Int(scrollSpeed)) px/sec")
                        .foregroundColor(.secondary)
                case .wordsPerMinute:
                    Slider(
                        value: $wordsPerMinute,
                        in: ScrollController.minimumWordsPerMinute...ScrollController.maximumWordsPerMinute,
                        step: 5
                    ) {
                        Text("Reading Pace")
                    }
                    Text("\(Int(wordsPerMinute)) words per minute")
                        .foregroundColor(.secondary)
                case .targetDuration:
                    Slider(
                        value: $targetDurationSeconds,
                        in: ScrollController.minimumTargetDuration...ScrollController.maximumTargetDuration,
                        step: 30
                    ) {
                        Text("Target Duration")
                    }
                    Text(durationText(targetDurationSeconds))
                        .foregroundColor(.secondary)
                }

                Text("WPM and Duration use the measured script height, so the selected script reaches the end at the requested pace.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Behavior") {
                Text("Scrolling is smooth and pauses while the pointer is over the overlay.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("When Scrolled to End", selection: $endBehavior) {
                    Text("Do Nothing").tag(0)
                    Text("Start Over").tag(1)
                    Text("Play Next Script").tag(2)
                }
            }
        }
        .padding()
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        if totalSeconds >= 3_600 {
            return String(
                format: "%d hr %02d min",
                totalSeconds / 3_600,
                (totalSeconds % 3_600) / 60
            )
        }
        return String(format: "%d min %02d sec", totalSeconds / 60, totalSeconds % 60)
    }
    
    // MARK: - Hotkeys Tab
    
    private var hotkeysTab: some View {
        Form {
            Section("Global Shortcuts") {
                Text("These fixed shortcuts are registered directly with macOS and do not require keyboard-monitoring permission.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                FixedHotkeyRow(label: "Speed Up", shortcut: HotkeyManager.Hotkey.speedUp.shortcut.display)
                FixedHotkeyRow(label: "Speed Down", shortcut: HotkeyManager.Hotkey.speedDown.shortcut.display)
                FixedHotkeyRow(label: "Pause/Resume", shortcut: HotkeyManager.Hotkey.togglePause.shortcut.display)
                FixedHotkeyRow(label: "Reset", shortcut: HotkeyManager.Hotkey.reset.shortcut.display)
                FixedHotkeyRow(label: "Toggle Overlay", shortcut: HotkeyManager.Hotkey.toggleOverlay.shortcut.display)
                FixedHotkeyRow(label: "Move to Next Display", shortcut: HotkeyManager.Hotkey.nextDisplay.shortcut.display)
            }
        }
        .padding()
    }
    
    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App icon and name
            VStack(spacing: 8) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)
                
                Text("Kyuva")
                    .font(.largeTitle.bold())
                
                Text(versionText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Your camera-side teleprompter")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("Capture visibility: The overlay may appear in screen shares or recordings. Verify the preview, or share a single app window that omits Kyuva.")
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 8) {
                Label(proAccessLabel, systemImage: "sparkles")
                    .font(.headline)

                Text("Voice Follow is the first Pro feature. It stays unlocked for everyone while the purchase preview is inactive.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if ProEntitlementStore.commerceEnabled {
                    HStack {
                        if proStore.accessState == .locked {
                            Button("Start 7-Day Trial") {
                                proStore.startTrial()
                            }
                        }

                        Button(proPurchaseLabel) {
                            Task {
                                proMessage = message(for: await proStore.purchaseLifetime())
                            }
                        }
                        .disabled(proStore.lifetimeProduct == nil || proStore.isLoading)

                        Button("Restore") {
                            Task {
                                proMessage = await proStore.restorePurchases()
                                    ? "Your lifetime purchase was restored."
                                    : "No verified lifetime purchase was found."
                            }
                        }
                    }
                } else {
                    Text("Open preview · no purchase available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let proMessage {
                    Text(proMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "mailto:support@kikuai.dev") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Send Feedback")
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    if let url = URL(string: "https://github.com/kiku-jw/kyuva") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Website")
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Button(action: {
                // Trigger Welcome Tour
                NotificationCenter.default.post(name: .init("ShowOnboarding"), object: nil)
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Show Welcome Guide")
                }
                .foregroundColor(.black)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            
            Spacer()
            
            Text(copyrightText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
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
            return "Pro Preview Unlocked"
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

struct FixedHotkeyRow: View {
    let label: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(shortcut)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}
