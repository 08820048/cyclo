import AppKit
import CycloCore

/// Hiding and unhiding the other apps, like ⌥⌘H but undoable.
@MainActor
enum AppHider {
    /// The regular, currently visible apps other than `target` and Cyclo itself.
    static func visibleApps(excluding target: NSRunningApplication?) -> [NSRunningApplication] {
        let me = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isHidden && !$0.isTerminated
                && $0.processIdentifier != me && $0.processIdentifier != target?.processIdentifier
        }
    }

    static func hide(_ apps: [NSRunningApplication]) {
        apps.forEach { $0.hide() }
    }

    static func unhide(_ hidden: [HiddenApp]) {
        for entry in hidden {
            if let app = NSRunningApplication(processIdentifier: entry.pid), app.bundleIdentifier == entry.bundleID {
                app.unhide()
            } else if let id = entry.bundleID {
                // Relaunched since (e.g. after a crash): unhide whatever instance is running now.
                NSRunningApplication.runningApplications(withBundleIdentifier: id).forEach { $0.unhide() }
            }
        }
    }
}

/// Dock auto-hide through System Events, which animates and does not restart the Dock.
enum DockController {
    static var autohide: Bool {
        (CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? Bool) ?? false
    }

    @discardableResult
    static func setAutohide(_ on: Bool) -> Bool {
        let source = "tell application \"System Events\" to set autohide of dock preferences to \(on)"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { NSLog("Cyclo: Dock autohide failed: \(error)") }
        return error == nil
    }
}

/// Runs a Shortcut by name; this is how Do Not Disturb gets toggled, since there is no public API for it.
enum FocusShortcut {
    static func run(_ name: String, wait: Bool = false) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            if wait { process.waitUntilExit() }
        } catch {
            NSLog("Cyclo: could not run Shortcut \(name): \(error)")
        }
    }
}
