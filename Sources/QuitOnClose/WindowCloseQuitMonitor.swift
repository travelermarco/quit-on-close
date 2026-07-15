import AppKit
import ApplicationServices

/// Watches every regular (Dock-visible) running application and, whenever one
/// of its windows is closed, checks whether it was the app's last remaining
/// window. If so, it quits the app - the same "close last window = exit"
/// behaviour Windows has, instead of the app lingering with no windows.
///
/// Implementation notes:
/// - Uses the Accessibility (AX) API to observe window creation/destruction
///   for every app, the same mechanism VoiceOver and window-management
///   utilities use. It requires the user to grant Accessibility access once.
/// - Only apps with `activationPolicy == .regular` are monitored, so
///   background/menu-bar-only agents (which normally have zero windows by
///   design) are automatically left alone.
/// - `app.terminate()` is used, not a force-kill, so the app gets the normal
///   chance to show "Save changes?" - identical to pressing Cmd+Q.
final class WindowCloseQuitMonitor {
    static let shared = WindowCloseQuitMonitor()

    private struct ObserverEntry {
        let observer: AXObserver
        let source: CFRunLoopSource
    }

    private var observers: [pid_t: ObserverEntry] = [:]
    private let excludedBundleIDs: Set<String>

    /// Small grace period before re-checking the window count after a window
    /// is destroyed. Some apps briefly replace one window with another (e.g.
    /// full-screen space transitions); this avoids quitting during that gap.
    private let quitCheckDelay: TimeInterval = 0.35

    /// Apps that were just launched need a moment before their AX server and
    /// first window(s) exist.
    private let attachDelayForNewLaunches: TimeInterval = 0.6

    private init() {
        excludedBundleIDs = ConfigStore.loadExcludedBundleIDs()
    }

    func start() {
        for runningApp in NSWorkspace.shared.runningApplications {
            attach(to: runningApp)
        }

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(applicationLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        Logger.log("Monitor attivo su \(observers.count) applicazioni.")
    }

    @objc private func applicationLaunched(_ note: Notification) {
        guard let runningApp = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + attachDelayForNewLaunches) { [weak self] in
            self?.attach(to: runningApp)
        }
    }

    @objc private func applicationTerminated(_ note: Notification) {
        guard let runningApp = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        detach(pid: runningApp.processIdentifier)
    }

    private func shouldMonitor(_ runningApp: NSRunningApplication) -> Bool {
        guard runningApp.activationPolicy == .regular else { return false }
        guard let bundleID = runningApp.bundleIdentifier else { return false }
        if bundleID == Bundle.main.bundleIdentifier { return false }
        if excludedBundleIDs.contains(bundleID) { return false }
        return true
    }

    private func attach(to runningApp: NSRunningApplication) {
        guard shouldMonitor(runningApp) else { return }
        let pid = runningApp.processIdentifier
        guard observers[pid] == nil else { return }

        var observerRef: AXObserver?
        guard AXObserverCreate(pid, axObserverCallback, &observerRef) == .success,
              let observer = observerRef else { return }

        let appElement = AXUIElementCreateApplication(pid)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // React to future windows being opened.
        AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, selfPtr)

        // Also watch every window that already exists at attach time.
        for window in standardWindows(of: appElement) {
            AXObserverAddNotification(observer, window, kAXUIElementDestroyedNotification as CFString, selfPtr)
        }

        let source = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)

        observers[pid] = ObserverEntry(observer: observer, source: source)
        Logger.log("Osservo \(runningApp.bundleIdentifier ?? "?") (pid \(pid)).")
    }

    private func detach(pid: pid_t) {
        guard let entry = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), entry.source, .defaultMode)
    }

    fileprivate func handleAXNotification(_ notification: CFString, element: AXUIElement, observer: AXObserver) {
        let name = notification as String

        if name == (kAXWindowCreatedNotification as String) {
            let selfPtr = Unmanaged.passUnretained(self).toOpaque()
            AXObserverAddNotification(observer, element, kAXUIElementDestroyedNotification as CFString, selfPtr)
            return
        }

        guard name == (kAXUIElementDestroyedNotification as String) else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid != 0 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + quitCheckDelay) { [weak self] in
            self?.quitIfNoWindowsRemain(pid: pid)
        }
    }

    private func quitIfNoWindowsRemain(pid: pid_t) {
        guard let runningApp = NSRunningApplication(processIdentifier: pid), !runningApp.isTerminated else { return }
        guard shouldMonitor(runningApp) else { return }

        let appElement = AXUIElementCreateApplication(pid)
        guard standardWindows(of: appElement).isEmpty else { return }

        Logger.log("Ultima finestra chiusa per \(runningApp.bundleIdentifier ?? "?"): chiudo l'app.")
        runningApp.terminate()
    }

    private func standardWindows(of appElement: AXUIElement) -> [AXUIElement] {
        var windowsRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        guard error == .success, let windows = windowsRef as? [AXUIElement] else { return [] }
        return windows.filter(isStandardWindow)
    }

    private func isStandardWindow(_ window: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
        guard let role = roleRef as? String, role == (kAXWindowRole as String) else { return false }

        var subroleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef)
        if let subrole = subroleRef as? String {
            return subrole == (kAXStandardWindowSubrole as String)
        }
        // No subrole reported: treat conservatively as a real window so we
        // never quit an app while something is still on screen.
        return true
    }
}

private func axObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let monitor = Unmanaged<WindowCloseQuitMonitor>.fromOpaque(refcon).takeUnretainedValue()
    monitor.handleAXNotification(notification, element: element, observer: observer)
}
