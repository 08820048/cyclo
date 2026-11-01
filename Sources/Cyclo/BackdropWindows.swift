import AppKit
import CycloCore
import SwiftUI

/// One borderless panel per screen, just above the desktop icons and below every app window.
/// It only covers things; nothing on the real desktop is touched, so there is nothing to restore.
@MainActor
final class BackdropWindows {
    private var panels: [NSPanel] = []
    private var backdrop: Backdrop?
    private var screenObserver: NSObjectProtocol?

    func show(_ backdrop: Backdrop) {
        self.backdrop = backdrop
        rebuild()
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in MainActor.assumeIsolated { self?.rebuild() } }
        }
    }

    func update(_ backdrop: Backdrop) {
        guard self.backdrop != nil, backdrop != self.backdrop else { return }
        show(backdrop)
    }

    func hide() {
        panels.forEach { $0.close() }
        panels = []
        backdrop = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
    }

    private func rebuild() {
        guard let backdrop else { return }
        panels.forEach { $0.close() }
        panels = NSScreen.screens.map { screen in
            // Non-activating so a click on the backdrop neither activates Cyclo nor reaches the
            // desktop (where "click wallpaper to reveal desktop" would sweep every window away).
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            panel.isReleasedWhenClosed = false
            panel.hasShadow = false
            panel.isOpaque = true
            panel.backgroundColor = .black
            panel.hidesOnDeactivate = false
            panel.animationBehavior = .none
            panel.contentView = NSHostingView(rootView: BackdropView(backdrop: backdrop))
            panel.setFrame(screen.frame, display: false)
            panel.orderFront(nil)
            return panel
        }
    }
}

struct BackdropView: View {
    let backdrop: Backdrop

    var body: some View {
        content.ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch backdrop {
        case .solid(let color):
            color.swiftUI
        case .gradient(let preset):
            LinearGradient(colors: preset.colors.map(\.swiftUI), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .image(let path):
            if let image = NSImage(contentsOfFile: path) {
                GeometryReader { proxy in
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                }
            } else {
                Color.black
            }
        }
    }
}

extension CycloColor {
    var swiftUI: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: ns.redComponent, green: ns.greenComponent, blue: ns.blueComponent)
    }
}
