import SwiftUI

@main
struct KyuvaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Open Kyuva…") {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Teleprompter") {
                Button("Open Prompt") {
                    NotificationCenter.default.post(name: .showOverlay, object: nil)
                }

                Divider()

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
