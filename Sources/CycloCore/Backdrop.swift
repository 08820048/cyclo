import Foundation

/// What the desktop is covered with while the stage is up.
public enum Backdrop: Codable, Equatable {
    case solid(CycloColor)
    case gradient(GradientPreset)
    case image(path: String)

    public static let `default` = Backdrop.gradient(.dusk)
}

public struct CycloColor: Codable, Equatable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red.clamped01
        self.green = green.clamped01
        self.blue = blue.clamped01
    }

    /// Accepts `#RRGGBB` or `RRGGBB`.
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    public var hex: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}

public enum GradientPreset: String, Codable, CaseIterable, Identifiable {
    case dusk, ocean, mint, graphite, paper

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dusk: "暮色"
        case .ocean: "海洋"
        case .mint: "薄荷"
        case .graphite: "石墨"
        case .paper: "纸白"
        }
    }

    public var colors: [CycloColor] {
        let hexes: [String] = switch self {
        case .dusk: ["#F5A47A", "#C4588C", "#4B3B8F"]
        case .ocean: ["#7FD3E6", "#2F7FC1", "#1B3A6B"]
        case .mint: ["#E3F6E8", "#9FD9B9", "#4E9E86"]
        case .graphite: ["#4A4D55", "#26282D", "#121316"]
        case .paper: ["#FBFAF7", "#EFEDE7", "#E2DFD6"]
        }
        return hexes.compactMap(CycloColor.init(hex:))
    }
}

extension Double {
    var clamped01: Double { Swift.min(1, Swift.max(0, self)) }
}
