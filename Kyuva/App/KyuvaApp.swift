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
                Button("Toggle Voice Follow") {
                    NotificationCenter.default.post(name: .toggleVoiceFollow, object: nil)
                }

                Button("Move to Next Display") {
                    appDelegate.moveOverlayToNextDisplay()
                }
            }
        }
    }
}
