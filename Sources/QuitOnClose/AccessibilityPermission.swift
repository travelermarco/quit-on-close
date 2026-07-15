import ApplicationServices

enum AccessibilityPermission {
    /// Returns true if already trusted; otherwise triggers the system
    /// "grant Accessibility access" prompt once and returns false.
    static func requestIfNeeded() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [key: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }
}
