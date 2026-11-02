import Foundation

/// A configuration with a name, so one Mac can keep an "App Store 截图" stage and a "教程录屏" stage.
public struct NamedScene: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var config: SceneConfig

    public init(id: UUID = UUID(), name: String, config: SceneConfig = SceneConfig()) {
        self.id = id
        self.name = name
        self.config = config
    }
}

/// All saved scenes and which one is selected. Never empty.
public struct SceneLibrary: Codable, Equatable {
    /// Scenes beyond this have no ⌃⌥⌘<number> shortcut.
    public static let shortcutCount = 9

    public private(set) var scenes: [NamedScene]
    public private(set) var selectedID: UUID

    public init(scenes: [NamedScene]? = nil) {
        let list = (scenes?.isEmpty == false ? scenes : nil) ?? [NamedScene(name: "默认")]
        self.scenes = list
        selectedID = list[0].id
    }

    /// A library holding the single configuration an older version saved.
    public init(migrating config: SceneConfig) {
        self.init(scenes: [NamedScene(name: "默认", config: config)])
    }

    public var selected: NamedScene { scenes.first { $0.id == selectedID } ?? scenes[0] }

    public var selectedConfig: SceneConfig {
        get { selected.config }
        set { update(selectedID) { $0.config = newValue } }
    }

    public mutating func select(_ id: UUID) {
        if scenes.contains(where: { $0.id == id }) { selectedID = id }
    }

    /// The scene a ⌃⌥⌘<number> shortcut opens; `number` counts from 1.
    public func scene(forShortcut number: Int) -> NamedScene? {
        scenes.indices.contains(number - 1) && number <= Self.shortcutCount ? scenes[number - 1] : nil
    }

    public func shortcutNumber(of id: UUID) -> Int? {
        guard let index = scenes.firstIndex(where: { $0.id == id }), index < Self.shortcutCount else { return nil }
        return index + 1
    }

    /// Adds a copy of the selected scene and selects it.
    @discardableResult
    public mutating func duplicateSelected() -> NamedScene {
        let copy = NamedScene(name: uniqueName(selected.name + " 副本"), config: selected.config)
        scenes.append(copy)
        selectedID = copy.id
        return copy
    }

    /// The last scene cannot be removed. Selection moves to the neighbour.
    public mutating func removeSelected() {
        guard scenes.count > 1, let index = scenes.firstIndex(where: { $0.id == selectedID }) else { return }
        scenes.remove(at: index)
        selectedID = scenes[min(index, scenes.count - 1)].id
    }

    public mutating func rename(_ id: UUID, to name: String) {
        update(id) { $0.name = name }
    }

    private mutating func update(_ id: UUID, _ change: (inout NamedScene) -> Void) {
        guard let index = scenes.firstIndex(where: { $0.id == id }) else { return }
        change(&scenes[index])
    }

    private func uniqueName(_ base: String) -> String {
        let taken = Set(scenes.map(\.name))
        if !taken.contains(base) { return base }
        return (2...).lazy.map { "\(base) \($0)" }.first { !taken.contains($0) }!
    }

    // MARK: Storage

    public static func decode(library: Data?, legacyScene: Data?) -> SceneLibrary {
        if let library, let decoded = try? JSONDecoder().decode(SceneLibrary.self, from: library), !decoded.scenes.isEmpty {
            return decoded
        }
        return SceneLibrary(migrating: SceneConfig.decode(legacyScene))
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }
}
