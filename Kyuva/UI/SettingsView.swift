import SwiftUI

struct SettingsView: View {
    @AppStorage("overlayOpacity") private var opacity: Double = 0.85
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("scrollSpeed") private var scrollSpeed: Double = 50
    @AppStorage("scrollMode") private var scrollMode: ScrollMode = .auto
    
    @StateObject private var scriptManager = ScriptManager.shared
    
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
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
    
    // MARK: - Script Tab
    
    private var scriptTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Scripts")
                    .font(.headline)
                Spacer()
                Button(action: { scriptManager.createNewScript() }) {
                    Image(systemName: "plus")
                }
                Button(action: { scriptManager.importScript() }) {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            
            // Script list
            List(selection: $scriptManager.selectedScriptId) {
                ForEach(scriptManager.scripts) { script in
                    Text(script.name)
                        .tag(script.id)
                }
                .onDelete { indexSet in
                    scriptManager.deleteScripts(at: indexSet)
                }
            }
            .frame(height: 100)
            
            // Script editor
            if let script = scriptManager.selectedScript {
                TextField("Script Name", text: Binding(
                    get: { script.name },
                    set: { scriptManager.updateScriptName(script.id, name: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                
                TextEditor(text: Binding(
                    get: { script.content },
                    set: { scriptManager.updateScriptContent(script.id, content: $0) }
                ))
                .font(.system(size: 14, design: .monospaced))
                .frame(minHeight: 150)
            } else {
                Text("Select or create a script")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
    
    // MARK: - Appearance Tab
    
    private var appearanceTab: some View {
        Form {
            Section("Overlay") {
                Slider(value: $opacity, in: 0.3...1.0) {
                    Text("Background Opacity")
                }
                Text("\(Int(opacity * 100))%")
                    .foregroundColor(.secondary)
            }
            
            Section("Text") {
                Slider(value: $fontSize, in: 12...36) {
                    Text("Font Size")
                }
                Text("\(Int(fontSize)) pt")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Scroll Tab
    
    private var scrollTab: some View {
        Form {
            Section("Mode") {
                Picker("Scroll Mode", selection: $scrollMode) {
                    Text("Auto Scroll").tag(ScrollMode.auto)
                    Text("Manual").tag(ScrollMode.manual)
                    Text("Voice Follow").tag(ScrollMode.voiceFollow)
                }
                .pickerStyle(.segmented)
            }
            
            if scrollMode == .auto {
                Section("Speed") {
                    Slider(value: $scrollSpeed, in: 10...200) {
                        Text("Scroll Speed")
                    }
                    Text("\(Int(scrollSpeed)) px/sec")
                        .foregroundColor(.secondary)
                }
            }
            
            if scrollMode == .voiceFollow {
                Section("Voice Settings") {
                    Text("Voice-follow requires microphone permission")
                        .foregroundColor(.secondary)
                    Button("Request Microphone Access") {
                        // TODO: Request mic permission
                    }
                }
            }
            
            Section("Behavior") {
                Toggle("Pause on hover", isOn: .constant(true))
                Toggle("Smooth scrolling", isOn: .constant(true))
            }
        }
        .padding()
    }
    
    // MARK: - Hotkeys Tab
    
    private var hotkeysTab: some View {
        Form {
            Section("Global Shortcuts") {
                HotkeyRow(label: "Speed Up", shortcut: "Shift + →")
                HotkeyRow(label: "Speed Down", shortcut: "Shift + ←")
                HotkeyRow(label: "Pause/Resume", shortcut: "Space")
                HotkeyRow(label: "Reset", shortcut: "Cmd + R")
                HotkeyRow(label: "Toggle Overlay", shortcut: "Cmd + T")
            }
        }
        .padding()
    }
}

struct HotkeyRow: View {
    let label: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(shortcut)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
                .font(.system(.caption, design: .monospaced))
        }
    }
}

enum ScrollMode: String, CaseIterable {
    case auto
    case manual
    case voiceFollow
}

#Preview {
    SettingsView()
}
