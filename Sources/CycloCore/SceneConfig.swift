import Foundation

/// Everything the user can configure about the stage.
public struct SceneConfig: Codable, Equatable {
    public var backdrop: Backdrop = .default
    public var hideOtherApps = true
    public var hideDock = true
    public var resizeWindow = true
    public var windowPreset = WindowPreset(width: 1440, height: 900)
    /// Covers the real menu bar with one that only shows the target app's menus.
    public var cleanMenuBar = true
    /// On that menu bar, replace the clock and status icons with a fixed 9:41 and a full battery.
    public var fixedStatus = true
    /// Names of Shortcuts that turn Do Not Disturb on / off. Empty means skip.
    public var focusOnShortcut = ""
    public var focusOffShortcut = ""

    public init() {}

    enum CodingKeys: String, CodingKey {
        case backdrop, hideOtherApps, hideDock, resizeWindow, windowPreset, cleanMenuBar, fixedStatus, focusOnShortcut, focusOffShortcut
    }

    // Missing keys fall back to defaults, so adding a setting never wipes a saved configuration.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SceneConfig()
        backdrop = (try? c.decodeIfPresent(Backdrop.self, forKey: .backdrop)) ?? d.backdrop
        hideOtherApps = try c.decodeIfPresent(Bool.self, forKey: .hideOtherApps) ?? d.hideOtherApps
        hideDock = try c.decodeIfPresent(Bool.self, forKey: .hideDock) ?? d.hideDock
        resizeWindow = try c.decodeIfPresent(Bool.self, forKey: .resizeWindow) ?? d.resizeWindow
        windowPreset = (try? c.decodeIfPresent(WindowPreset.self, forKey: .windowPreset)) ?? d.windowPreset
        cleanMenuBar = try c.decodeIfPresent(Bool.self, forKey: .cleanMenuBar) ?? d.cleanMenuBar
        fixedStatus = try c.decodeIfPresent(Bool.self, forKey: .fixedStatus) ?? d.fixedStatus
        focusOnShortcut = try c.decodeIfPresent(String.self, forKey: .focusOnShortcut) ?? d.focusOnShortcut
        focusOffShortcut = try c.decodeIfPresent(String.self, forKey: .focusOffShortcut) ?? d.focusOffShortcut
    }

    public static func decode(_ data: Data?) -> SceneConfig {
        data.flatMap { try? JSONDecoder().decode(SceneConfig.self, from: $0) } ?? SceneConfig()
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }
}
