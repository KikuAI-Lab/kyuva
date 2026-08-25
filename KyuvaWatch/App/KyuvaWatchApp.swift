import SwiftUI

@main
struct KyuvaWatchApp: App {
    @StateObject private var session = WatchSessionController()

    var body: some Scene {
        WindowGroup {
            WatchRemoteView()
                .environmentObject(session)
        }
    }
}
