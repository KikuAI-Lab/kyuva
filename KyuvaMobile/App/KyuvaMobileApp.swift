import SwiftUI

@main
struct KyuvaMobileApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scriptManager = ScriptManager.shared

    init() {
        PhoneWatchSession.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            MobileEditorView()
                .environmentObject(scriptManager)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        MacRemoteClient.shared.stop()
                        scriptManager.flushPendingSave()
                    }
                }
        }
    }
}
