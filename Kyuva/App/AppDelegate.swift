import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    private var statusItem: NSStatusItem?
    private var overlayWindowController: OverlayWindowController?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var shouldShowOverlayAfterOnboarding = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        print("[Kyuva] Starting up, hasCompletedOnboarding: \(completed)")
        
        setupStatusBarItem()
        setupOverlayWindow(isVisible: false)
        
        // Listen for onboarding triggers from UI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showOnboardingManual),
            name: .showOnboarding,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .showSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showOverlay),
            name: .showOverlay,
            object: nil
        )
        
        // Kyuva remains a menu-bar agent throughout onboarding; the welcome
        // window can become key without adding a temporary Dock icon.
        if !completed {
            print("[Kyuva] Showing onboarding...")
            showOnboarding(showOverlayOnClose: false)
        } else {
            print("[Kyuva] Skipping onboarding, already completed")
            openSettings()
        }
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Kyuva")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Kyuva", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Prompt", action: #selector(showOverlay), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Hide Prompt", action: #selector(hideOverlay), keyEquivalent: "h"))
        let nextDisplayItem = NSMenuItem(
            title: "Move to Next Display",
            action: #selector(moveOverlayToNextDisplay),
            keyEquivalent: ""
        )
        menu.addItem(nextDisplayItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Welcome Guide…", action: #selector(showOnboardingManual), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Kyuva", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupOverlayWindow(isVisible: Bool) {
        overlayWindowController = OverlayWindowController()
        if isVisible {
            overlayWindowController?.showOverlay()
        } else {
            overlayWindowController?.hideOverlay()
        }
    }
    
    private func showOnboarding(showOverlayOnClose: Bool) {
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        shouldShowOverlayAfterOnboarding = showOverlayOnClose
        
        let onboardingView = OnboardingHostView(
            onDismiss: { [weak self] in
                self?.onboardingWindow?.close()
            }
        )
        
        onboardingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 670, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        onboardingWindow?.isReleasedWhenClosed = false
        onboardingWindow?.title = "Welcome to Kyuva"
        onboardingWindow?.contentView = NSHostingView(rootView: onboardingView)
        onboardingWindow?.delegate = self
        onboardingWindow?.center()
        // Make sure it appears above everything
        onboardingWindow?.level = .floating
        onboardingWindow?.makeKeyAndOrderFront(nil)
        onboardingWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showOnboardingManual() {
        showOnboarding(
            showOverlayOnClose: overlayWindowController?.isOverlayVisible ?? false
        )
    }
    
    @objc private func showOverlay() {
        overlayWindowController?.showOverlay()
    }
    
    @objc private func hideOverlay() {
        overlayWindowController?.hideOverlay()
    }

    @objc func moveOverlayToNextDisplay() {
        overlayWindowController?.moveToNextDisplay()
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1080, height: 680),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.title = "Kyuva"
            settingsWindow?.minSize = NSSize(width: 920, height: 580)
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.delegate = self
            settingsWindow?.center()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        ScriptManager.shared.flushPendingSave()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }

        if closingWindow === onboardingWindow {
            let shouldShowOverlay = shouldShowOverlayAfterOnboarding

            // Defer overlay restoration until AppKit finishes the close event.
            DispatchQueue.main.async { [weak self] in
                self?.onboardingWindow = nil
                if shouldShowOverlay {
                    self?.overlayWindowController?.showOverlay()
                } else {
                    self?.overlayWindowController?.hideOverlay()
                    self?.openSettings()
                }
            }
        } else if closingWindow === settingsWindow {
            DispatchQueue.main.async { [weak self] in
                self?.settingsWindow = nil
            }
        }
    }
}

// Helper view to handle onboarding dismissal
struct OnboardingHostView: View {
    var onDismiss: () -> Void
    @State private var isPresented = true
    
    var body: some View {
        OnboardingView(isPresented: $isPresented)
            .onChange(of: isPresented) { newValue in
                if !newValue {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    onDismiss()
                }
            }
    }
}
