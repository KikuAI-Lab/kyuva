import Foundation
import AppKit
import UniformTypeIdentifiers
import Combine

/// Manages scripts: CRUD, tokenization, import/export
class ScriptManager: ObservableObject {
    
    static let shared = ScriptManager()
    
    @Published var scripts: [Script] = []
    @Published var selectedScriptId: UUID?
    
    var selectedScript: Script? {
        scripts.first { $0.id == selectedScriptId }
    }
    
    /// Lines from the currently selected script
    var lines: [String] {
        selectedScript?.lines ?? []
    }
    
    /// Tokenized words for voice-sync matching
    var tokens: [Token] {
        selectedScript?.tokens ?? []
    }
    
    private let storage: LocalStore
    
    init(storage: LocalStore = LocalStore()) {
        self.storage = storage
        loadScripts()
        
        // Select first script by default
        if selectedScriptId == nil, let first = scripts.first {
            selectedScriptId = first.id
        }
        
        // Create default script if none exist
        if scripts.isEmpty {
            createNewScript()
        }
    }
    
    // MARK: - CRUD
    
    func createNewScript() {
        let script = Script(
            name: "New Script",
            content: defaultScriptContent
        )
        scripts.append(script)
        selectedScriptId = script.id
        saveScripts()
    }
    
    func deleteScripts(at indexSet: IndexSet) {
        scripts.remove(atOffsets: indexSet)
        if !scripts.contains(where: { $0.id == selectedScriptId }) {
            selectedScriptId = scripts.first?.id
        }
        saveScripts()
    }
    
    func updateScriptName(_ id: UUID, name: String) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[index].name = name
        saveScripts()
    }
    
    func updateScriptContent(_ id: UUID, content: String) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[index].content = content
        scripts[index].reindex()
        saveScripts()
    }
    
    // MARK: - Import/Export
    
    func importScript() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let name = url.deletingPathExtension().lastPathComponent
                let script = Script(name: name, content: content)
                scripts.append(script)
                selectedScriptId = script.id
                saveScripts()
            } catch {
                print("Failed to import script: \(error)")
            }
        }
    }
    
    func exportScript(_ script: Script) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(script.name).txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try script.content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to export script: \(error)")
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadScripts() {
        scripts = storage.loadScripts()
    }
    
    private func saveScripts() {
        storage.saveScripts(scripts)
    }
    
    // MARK: - Default Content
    
    private var defaultScriptContent: String {
        """
        Welcome to Kyuva 👋
        
        This text sits right next to your camera,
        so you can read notes while keeping natural eye contact.
        
        • Hover over the overlay to pause
        • Use Shift + ← / → to adjust speed
        • Press Space to pause/resume
        
        Replace this with your script, meeting notes,
        or bullet points.
        
        Quick tip: Keep phrases short.
        One thought per line reads best.
        
        You're ready to sound confident
        and look like you're not reading. ✨
        """
    }
}

// MARK: - Models

struct Script: Identifiable, Codable {
    let id: UUID
    var name: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    
    // Non-persisted, computed on load
    var lines: [String] = []
    var tokens: [Token] = []
    
    enum CodingKeys: String, CodingKey {
        case id, name, content, createdAt, updatedAt
    }
    
    init(name: String, content: String) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
        reindex()
    }
    
    mutating func reindex() {
        // Split into lines
        lines = content
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Tokenize for voice-sync
        tokens = []
        for (lineIndex, line) in lines.enumerated() {
            let words = line
                .lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { !$0.isEmpty }
            
            for word in words {
                tokens.append(Token(
                    word: word,
                    lineIndex: lineIndex,
                    isAnchor: word.count > 6 // Longer words are anchors
                ))
            }
        }
    }
}

struct Token: Codable {
    let word: String
    let lineIndex: Int
    let isAnchor: Bool
}
