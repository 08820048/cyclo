import AppKit
import CoreGraphics
import CycloCore
import Observation
import SwiftUI

/// Shows pressed shortcuts as keycaps near the bottom of the screen. Watching keys needs the
/// "Input Monitoring" permission; without it the monitor simply hears nothing.
@MainActor
final class KeyDisplay {
    private let model = KeyDisplayModel()
    private var panel: NSPanel?
    private var monitor: Any?
    private var hideTask: Task<Void, Never>?
    private var typing = false

    var isRunning: Bool { monitor != nil }
    static var hasPermission: Bool { CGPreflightListenEventAccess() }
    static func requestPermission() { _ = CGRequestListenEventAccess() }

    func start(typing: Bool) {
        self.typing = typing
        guard monitor == nil else { return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 120), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Above the stand-in menu bar and the click rings.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        panel.isReleasedWhenClosed = false
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(rootView: KeycapsView(model: model))
        self.panel = panel

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard !event.isARepeat else { return }
            let flags = event.modifierFlags
            var modifiers: KeyModifiers = []
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.shift) { modifiers.insert(.shift) }
            if flags.contains(.command) { modifiers.insert(.command) }
            let keyCode = event.keyCode
            let character = event.charactersIgnoringModifiers
            MainActor.assumeIsolated { self?.press(keyCode: keyCode, character: character, modifiers: modifiers) }
        }
    }

    func updateTyping(_ typing: Bool) { self.typing = typing }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        hideTask?.cancel()
        panel?.close()
        panel = nil
        model.keycaps = []
    }

    private func press(keyCode: UInt16, character: String?, modifiers: KeyModifiers) {
        guard let caps = KeyLabel.keycaps(keyCode: keyCode, character: character, modifiers: modifiers, typing: typing), let panel else { return }
        // Typed characters pile up into a short run; a shortcut replaces whatever was showing.
        let isShortcut = !modifiers.isDisjoint(with: [.control, .option, .command]) || caps.count > 1
        if typing, !isShortcut, caps.count == 1, caps[0].count == 1, model.isTyping {
            model.keycaps = Array((model.keycaps + caps).suffix(12))
        } else {
            model.keycaps = caps
            model.isTyping = typing && !isShortcut && caps.count == 1 && caps[0].count == 1
        }
        model.visible = true

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.minY + 90))
        panel.orderFront(nil)

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.model.visible = false
            self?.model.isTyping = false
        }
    }
}

@MainActor
@Observable
final class KeyDisplayModel {
    var keycaps: [String] = []
    var visible = false
    var isTyping = false
}

private struct KeycapsView: View {
    let model: KeyDisplayModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(model.keycaps.enumerated()), id: \.offset) { _, cap in
                Text(cap)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 52, minHeight: 52)
                    .padding(.horizontal, cap.count > 2 ? 12 : 0)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.black.opacity(0.72)))
        .opacity(model.visible && !model.keycaps.isEmpty ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: model.visible)
        .frame(width: 600, height: 120)
    }
}
