import SwiftUI

@main
struct KyuvaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandMenu("Teleprompter") {
                Button("Move to Next Display") {
                    appDelegate.moveOverlayToNextDisplay()
                }
            }
        }
    }
}
