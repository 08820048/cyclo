import AppKit
import QuartzCore

/// A ring that blooms where the mouse is clicked, for recordings. It is an overlay that lets every
/// click through, and watching mouse buttons needs no extra permission.
@MainActor
final class ClickHighlighter {
    private var panels: [(panel: NSPanel, layer: CALayer)] = []
    private var monitor: Any?
    private var screenObserver: NSObjectProtocol?

    var isRunning: Bool { monitor != nil }

    func start() {
        guard monitor == nil else { return }
        rebuild()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            let point = NSEvent.mouseLocation
            MainActor.assumeIsolated { self?.ring(at: point) }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.rebuild() } }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        panels.forEach { $0.panel.close() }
        panels = []
    }

    private func rebuild() {
        panels.forEach { $0.panel.close() }
        panels = NSScreen.screens.map { screen in
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            // Above the stand-in menu bar, so a click up there is shown too.
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            panel.isReleasedWhenClosed = false
            panel.hasShadow = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.animationBehavior = .none
            let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            panel.contentView = view
            panel.setFrame(screen.frame, display: false)
            panel.orderFront(nil)
            return (panel, view.layer!)
        }
    }

    private func ring(at location: NSPoint) {
        guard let entry = panels.first(where: { $0.panel.frame.contains(location) }) else { return }
        let size: CGFloat = 56
        let center = CGPoint(x: location.x - entry.panel.frame.minX, y: location.y - entry.panel.frame.minY)

        let ring = CAShapeLayer()
        ring.frame = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        ring.path = CGPath(ellipseIn: ring.bounds.insetBy(dx: 3, dy: 3), transform: nil)
        ring.fillColor = NSColor.systemYellow.withAlphaComponent(0.28).cgColor
        ring.strokeColor = NSColor.systemYellow.cgColor
        ring.lineWidth = 3
        entry.layer.addSublayer(ring)

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.55
        grow.toValue = 1.35
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        for animation in [grow, fade] {
            animation.duration = 0.5
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
        }
        ring.add(grow, forKey: "grow")
        ring.add(fade, forKey: "fade")
        CATransaction.commit()
    }
}
