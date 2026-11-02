import AppKit
import ApplicationServices
import CycloCore
import SwiftUI

/// A stand-in for the real menu bar: the target app's menus on the left, a fixed 9:41 and a full
/// battery on the right. It only covers the real bar, so there is nothing to restore, and a crash
/// takes it away with the process.
@MainActor
final class MenuBarCover {
    private var panels: [NSPanel] = []
    private var content: Content?
    private var screenObserver: NSObjectProtocol?
    /// Called by ⌥-click or the right-click menu: the cover hides Cyclo's own menu bar icon, so it offers a way out.
    var onExit: (() -> Void)?

    struct Content: Equatable {
        var appName: String
        var menus: [String]
        var backdrop: Backdrop
        var fixedStatus: Bool
    }

    func show(_ content: Content) {
        self.content = content
        rebuild()
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in MainActor.assumeIsolated { self?.rebuild() } }
        }
    }

    /// Settings changed while the stage is up.
    func update(backdrop: Backdrop, fixedStatus: Bool) {
        guard var content, content.backdrop != backdrop || content.fixedStatus != fixedStatus else { return }
        content.backdrop = backdrop
        content.fixedStatus = fixedStatus
        show(content)
    }

    var isShowing: Bool { content != nil }

    func hide() {
        panels.forEach { $0.close() }
        panels = []
        content = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
    }

    private func rebuild() {
        guard let content else { return }
        panels.forEach { $0.close() }
        panels = NSScreen.screens.compactMap { screen in
            let height = Self.barHeight(of: screen)
            guard height > 0 else { return nil }  // menu bar is auto-hidden on this screen
            let frame = NSRect(x: screen.frame.minX, y: screen.frame.maxY - height, width: screen.frame.width, height: height)
            // Above the status items (and so above Cyclo's own), below the menus a click would open.
            // Not ignoring the mouse: clicks must land here, not on the real menu bar underneath.
            let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            panel.isReleasedWhenClosed = false
            panel.hasShadow = false
            panel.isOpaque = true
            panel.backgroundColor = .black
            panel.hidesOnDeactivate = false
            panel.animationBehavior = .none
            let hosting = NSHostingView(rootView: MenuBarCoverView(content: content, screenSize: screen.frame.size, barHeight: height))
            panel.contentView = ExitCatcherView(content: hosting) { [weak self] in self?.onExit?() }
            panel.setFrame(frame, display: false)
            panel.orderFront(nil)
            return panel
        }
    }

    /// Menu bar thickness; notched screens report it through the safe area. 0 when the bar is hidden.
    static func barHeight(of screen: NSScreen) -> CGFloat {
        if screen.safeAreaInsets.top > 0 { return screen.safeAreaInsets.top }
        return max(0, screen.frame.maxY - screen.visibleFrame.maxY)
    }

    /// Titles of the app's top-level menus (without the Apple menu), read through Accessibility.
    /// Empty when there is no permission or the app does not answer in time.
    static func menuTitles(of pid: pid_t) -> [String] {
        guard AXIsProcessTrusted() else { return [] }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        var bar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &bar) == .success, let bar else { return [] }
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(bar as! AXUIElement, kAXChildrenAttribute as CFString, &children) == .success,
              let items = children as? [AXUIElement] else { return [] }
        // The first item is the Apple menu, the second the app's own menu (already shown in bold).
        return items.dropFirst(2).compactMap { item in
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &title)
            return (title as? String).flatMap { $0.isEmpty ? nil : $0 }
        }
    }
}

/// Holds the cover's content and turns ⌥-click and right-click into a way to end the stage.
private final class ExitCatcherView: NSView {
    private let onExit: () -> Void

    init(content: NSView, onExit: @escaping () -> Void) {
        self.onExit = onExit
        super.init(frame: .zero)
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) { onExit() }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let item = NSMenuItem(title: "退出舞台", action: #selector(exitStage), keyEquivalent: "s")
        item.keyEquivalentModifierMask = [.control, .option, .command]
        item.target = self
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func exitStage() { onExit() }
}

private struct MenuBarCoverView: View {
    let content: MenuBarCover.Content
    let screenSize: CGSize
    let barHeight: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            // The same backdrop as the desktop, so the bar looks like part of it, then a tint for legible text.
            BackdropView(backdrop: content.backdrop)
                .frame(width: screenSize.width, height: screenSize.height)
            Color.black.opacity(0.28)
        }
        .frame(width: screenSize.width, height: barHeight, alignment: .top)
        .clipped()
        .overlay { bar }
    }

    private var bar: some View {
        HStack(spacing: 0) {
            Image(systemName: "apple.logo").font(.system(size: 14, weight: .medium)).padding(.horizontal, 12)
            Text(content.appName).fontWeight(.bold).padding(.trailing, 14)
            ForEach(content.menus, id: \.self) { Text($0).padding(.trailing, 14) }
            Spacer()
            if content.fixedStatus {
                HStack(spacing: 14) {
                    Image(systemName: "battery.100percent")
                    Image(systemName: "wifi")
                    Image(systemName: "magnifyingglass")
                    Text("9:41")
                }
                .padding(.trailing, 14)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
        .lineLimit(1)
    }
}
