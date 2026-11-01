import Foundation

/// A target window size in points (on Retina, pixels are twice this).
public struct WindowPreset: Codable, Equatable, Hashable, CustomStringConvertible {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// Parses "1280x800", "1280×800", "1280 * 800" and the like.
    public init?(string: String) {
        let parts = string.lowercased()
            .split(whereSeparator: { "x×* ,".contains($0) })
            .compactMap { Int($0) }
        guard parts.count == 2, Self.valid(parts[0]), Self.valid(parts[1]) else { return nil }
        self.init(width: parts[0], height: parts[1])
    }

    public var description: String { "\(width) × \(height)" }
    public var size: CGSize { CGSize(width: width, height: height) }

    public static let builtins: [WindowPreset] = [
        WindowPreset(width: 1280, height: 800),
        WindowPreset(width: 1440, height: 900),
        WindowPreset(width: 1600, height: 1000),
        WindowPreset(width: 1280, height: 720),
        WindowPreset(width: 1920, height: 1080),
        WindowPreset(width: 2560, height: 1600),
    ]

    static func valid(_ v: Int) -> Bool { (200...10_000).contains(v) }
}
