import Foundation

public struct KeyModifiers: OptionSet, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let control = KeyModifiers(rawValue: 1)
    public static let option = KeyModifiers(rawValue: 2)
    public static let shift = KeyModifiers(rawValue: 4)
    public static let command = KeyModifiers(rawValue: 8)
}

/// What to show for a key press during a recording, as separate keycaps: ["⌘", "⇧", "4"].
public enum KeyLabel {
    /// Keys with a name of their own, by virtual key code.
    static let special: [UInt16: String] = [
        36: "↩", 76: "⌅", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦", 53: "esc",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    /// `character` is what the key types without modifiers. Returns nil for presses that should not be shown:
    /// plain typing (possibly a password, a message) unless `typing` is on, and bare Shift (capital letters).
    public static func keycaps(keyCode: UInt16, character: String?, modifiers: KeyModifiers, typing: Bool) -> [String]? {
        let name: String
        if let named = special[keyCode] {
            name = named
        } else if let character, let first = character.unicodeScalars.first, first.value >= 0x20, first.value != 0x7F {
            name = character.uppercased()
        } else {
            return nil
        }

        let isShortcut = !modifiers.isDisjoint(with: [.control, .option, .command])
        let isNamedKey = special[keyCode] != nil
        guard isShortcut || isNamedKey || typing else { return nil }
        // A named key such as Return is only worth showing alone when it is not part of typing.
        if !isShortcut, isNamedKey, !typing, ["Space", "⌫", "⌦", "↩", "⌅"].contains(name) { return nil }

        var caps: [String] = []
        if modifiers.contains(.control) { caps.append("⌃") }
        if modifiers.contains(.option) { caps.append("⌥") }
        if modifiers.contains(.shift) { caps.append("⇧") }
        if modifiers.contains(.command) { caps.append("⌘") }
        caps.append(name)
        return caps
    }
}
