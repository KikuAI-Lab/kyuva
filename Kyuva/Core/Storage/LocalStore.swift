import Foundation

/// Local JSON storage for scripts and settings
class LocalStore {
    
    private let scriptsURL: URL
    private let backupURL: URL
    private let saveQueue: DispatchQueue
    
    init(
        directoryURL: URL? = nil,
        saveQueue: DispatchQueue? = nil
    ) {
        self.saveQueue = saveQueue ?? DispatchQueue(label: "com.kyuva.storage", qos: .background)

#if DEBUG
        let debugDirectory = ProcessInfo.processInfo.environment["KYUVA_STORAGE_DIRECTORY"]
            .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
#else
        let debugDirectory: URL? = nil
#endif

        let storageDirectory: URL
        if let directoryURL {
            storageDirectory = directoryURL
        } else if let debugDirectory {
            storageDirectory = debugDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            storageDirectory = appSupport.appendingPathComponent("Kyuva", isDirectory: true)
        }
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        scriptsURL = storageDirectory.appendingPathComponent("scripts.json")
        backupURL = storageDirectory.appendingPathComponent("scripts.backup.json")
    }
    
    // MARK: - Scripts
    
    func loadScripts() -> [Script] {
        guard FileManager.default.fileExists(atPath: scriptsURL.path) else {
            return (try? decodeScripts(at: backupURL)) ?? []
        }
        
        do {
            return try decodeScripts(at: scriptsURL)
        } catch {
            let preservedURL = preserveCorruptPrimary()
            if let recovered = try? decodeScripts(at: backupURL) {
                print("[Kyuva] Recovered scripts from the last known-good backup. Corrupt data preserved at \(preservedURL?.path ?? "an unavailable path").")
                return recovered
            }

            print("[Kyuva] Failed to load scripts or backup: \(error). Corrupt data preserved at \(preservedURL?.path ?? "an unavailable path").")
            return []
        }
    }
    
    func saveScripts(_ scripts: [Script]) {
        let scriptsCopy = scripts // Capture copy for thread safety
        saveQueue.async {
            do {
                let data = try JSONEncoder().encode(scriptsCopy)
                if FileManager.default.fileExists(atPath: self.scriptsURL.path),
                   let currentData = try? Data(contentsOf: self.scriptsURL),
                   (try? self.decodeScripts(from: currentData)) != nil {
                    try currentData.write(to: self.backupURL, options: .atomic)
                }

                // Data's atomic option writes a complete replacement file, so a
                // crash cannot leave a partially encoded scripts document.
                try data.write(to: self.scriptsURL, options: .atomic)
            } catch {
                print("Failed to save scripts: \(error)")
            }
        }
    }

    /// Wait for queued writes to finish. Used by deterministic local round-trip tests.
    func waitForPendingWrites() {
        saveQueue.sync { }
    }

    private func decodeScripts(at url: URL) throws -> [Script] {
        try decodeScripts(from: Data(contentsOf: url))
    }

    private func decodeScripts(from data: Data) throws -> [Script] {
        var scripts = try JSONDecoder().decode([Script].self, from: data)
        for index in scripts.indices {
            scripts[index].reindex()
        }
        return scripts
    }

    @discardableResult
    private func preserveCorruptPrimary() -> URL? {
        let directory = scriptsURL.deletingLastPathComponent()
        let preservedURL = directory.appendingPathComponent(
            "scripts.corrupt-\(UUID().uuidString).json"
        )

        do {
            try FileManager.default.copyItem(at: scriptsURL, to: preservedURL)
            return preservedURL
        } catch {
            print("[Kyuva] Could not preserve corrupt scripts: \(error)")
            return nil
        }
    }
}
