import AppKit
import ApplicationServices
import CycloCore

/// Resizes and centres the target app's front window through the Accessibility API.
@MainActor
enum WindowSizer {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that sends the user to Privacy & Security › Accessibility.
    static func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func frontWindow(of pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(app, attribute as CFString, &value) == .success, let value,
               CFGetTypeID(value) == AXUIElementGetTypeID() {
                return (value as! AXUIElement)
            }
        }
        return nil
    }

    static func snapshot(of window: AXUIElement, pid: pid_t) -> WindowSnapshot? {
        guard let origin = point(window, kAXPositionAttribute), let size = size(window) else { return nil }
        return WindowSnapshot(pid: pid, origin: origin, size: size)
    }

    /// Sizes `window` to `preset` (scaled down if the screen is too small) and centres it on its screen.
    /// Returns the size the app actually accepted; apps may enforce their own minimum or maximum.
    @discardableResult
    static func apply(_ preset: WindowPreset, to window: AXUIElement) -> CGSize? {
        guard let primary = NSScreen.screens.first, let origin = point(window, kAXPositionAttribute), let current = size(window) else { return nil }
        let primaryHeight = primary.frame.height
        let frame = Geometry.appKitRect(axOrigin: origin, size: current, primaryHeight: primaryHeight)
        let screen = NSScreen.screens.max { overlap($0.frame, frame) < overlap($1.frame, frame) } ?? primary
        let area = Geometry.stageArea(screenFrame: screen.frame, visibleFrame: screen.visibleFrame)

        // Move first so the app sizes against the right screen, then centre on the size it accepted.
        let target = Geometry.fitted(preset.size, in: area.size)
        set(window, position: Geometry.axOrigin(of: Geometry.centered(target, in: area), primaryHeight: primaryHeight))
        set(window, size: target)
        let accepted = size(window) ?? target
        set(window, position: Geometry.axOrigin(of: Geometry.centered(accepted, in: area), primaryHeight: primaryHeight))
        return accepted
    }

    static func restore(_ snapshot: WindowSnapshot, window: AXUIElement? = nil) {
        guard let window = window ?? frontWindow(of: snapshot.pid) else { return }
        set(window, size: snapshot.size)
        set(window, position: snapshot.origin)
        set(window, size: snapshot.size)
    }

    /// The target's other standard, visible windows, with how to find each again.
    static func otherWindows(of pid: pid_t, keeping front: AXUIElement) -> [(element: AXUIElement, record: MinimizedWindow)] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        return windows(of: app).compactMap { window in
            guard !CFEqual(window, front), bool(window, kAXMinimizedAttribute) == false,
                  string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole,
                  let origin = point(window, kAXPositionAttribute), let size = size(window) else { return nil }
            return (window, MinimizedWindow(pid: pid, title: string(window, kAXTitleAttribute) ?? "", origin: origin, size: size))
        }
    }

    static func minimize(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    /// Brings back windows `minimize` took away; ones the user already restored or closed are skipped.
    static func unminimize(_ records: [MinimizedWindow]) {
        for pid in Set(records.map(\.pid)) {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.5)
            let wanted = records.filter { $0.pid == pid }
            for window in windows(of: app) where bool(window, kAXMinimizedAttribute) == true {
                guard let origin = point(window, kAXPositionAttribute), let size = size(window) else { continue }
                let title = string(window, kAXTitleAttribute) ?? ""
                if wanted.contains(where: { $0.matches(title: title, origin: origin, size: size) }) {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                }
            }
        }
    }

    // MARK: AX values

    private static func windows(of app: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? Bool
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }


    private static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    private static func size(_ element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }

    private static func set(_ element: AXUIElement, position: CGPoint) {
        var p = position
        if let value = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value) }
    }

    private static func set(_ element: AXUIElement, size: CGSize) {
        var s = size
        if let value = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value) }
    }

    private static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
    }
}
