import Foundation

/// Local JSON storage for scripts and settings
class LocalStore {
    
    private let scriptsURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let kyuvaDir = appSupport.appendingPathComponent("Kyuva", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: kyuvaDir, withIntermediateDirectories: true)
        
        scriptsURL = kyuvaDir.appendingPathComponent("scripts.json")
    }
    
    // MARK: - Scripts
    
    func loadScripts() -> [Script] {
        guard FileManager.default.fileExists(atPath: scriptsURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: scriptsURL)
            var scripts = try JSONDecoder().decode([Script].self, from: data)
            
            // Reindex tokens (not persisted)
            for i in scripts.indices {
                scripts[i].reindex()
            }
            
            return scripts
        } catch {
            print("Failed to load scripts: \(error)")
            return []
        }
    }
    
    func saveScripts(_ scripts: [Script]) {
        do {
            let data = try JSONEncoder().encode(scripts)
            try data.write(to: scriptsURL)
        } catch {
            print("Failed to save scripts: \(error)")
        }
    }
}
