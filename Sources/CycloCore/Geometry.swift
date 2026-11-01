import CoreGraphics

/// Window placement math. AppKit rects have a bottom-left origin on the primary screen;
/// the Accessibility API uses a top-left origin on the same screen.
public enum Geometry {
    /// `size` scaled down (keeping its aspect ratio) until it fits in `available`. Never scaled up.
    public static func fitted(_ size: CGSize, in available: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return size }
        let scale = min(1, available.width / size.width, available.height / size.height)
        return CGSize(width: (size.width * scale).rounded(.down), height: (size.height * scale).rounded(.down))
    }

    public static func centered(_ size: CGSize, in rect: CGRect) -> CGRect {
        CGRect(x: (rect.midX - size.width / 2).rounded(), y: (rect.midY - size.height / 2).rounded(),
               width: size.width, height: size.height)
    }

    /// Top-left corner, in Accessibility coordinates, of an AppKit rect.
    public static func axOrigin(of rect: CGRect, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX, y: primaryHeight - rect.maxY)
    }

    /// The AppKit rect of a window the Accessibility API reports at `origin` with `size`.
    public static func appKitRect(axOrigin origin: CGPoint, size: CGSize, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: origin.x, y: primaryHeight - origin.y - size.height, width: size.width, height: size.height)
    }

    /// A screen's frame minus the menu bar strip at its top.
    public static func stageArea(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let menuBar = max(0, screenFrame.maxY - visibleFrame.maxY)
        return CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: screenFrame.height - menuBar)
    }
}
