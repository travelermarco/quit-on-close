import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var permissionPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Logger.log("QuitOnClose avviato (pid \(ProcessInfo.processInfo.processIdentifier)).")
        waitForAccessibilityPermissionThenStart()
    }

    private func waitForAccessibilityPermissionThenStart() {
        // This prompts the system Accessibility permission dialog exactly once
        // if the permission has not already been granted.
        if AccessibilityPermission.requestIfNeeded() {
            Logger.log("Permesso di Accessibilita' gia' concesso. Avvio il monitor.")
            WindowCloseQuitMonitor.shared.start()
            return
        }

        Logger.log("In attesa che l'utente conceda il permesso di Accessibilita'...")
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard AccessibilityPermission.isTrusted() else { return }
            timer.invalidate()
            self?.permissionPollTimer = nil
            Logger.log("Permesso di Accessibilita' concesso. Avvio il monitor.")
            WindowCloseQuitMonitor.shared.start()
        }
    }
}
