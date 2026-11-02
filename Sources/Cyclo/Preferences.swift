import Foundation
import Observation
import CycloCore

@MainActor
@Observable
final class Preferences {
    static let shared = Preferences()
    private static let libraryKey = "library"
    private static let legacyKey = "scene"

    /// Every saved scene. Changes are saved and announced.
    private(set) var library: SceneLibrary {
        didSet {
            guard library != oldValue else { return }
            UserDefaults.standard.set(library.encoded(), forKey: Self.libraryKey)
            onChange?()
        }
    }

    /// The selected scene's configuration; everything that reads or edits "the" configuration goes through here.
    var scene: SceneConfig {
        get { library.selectedConfig }
        set { library.selectedConfig = newValue }
    }

    @ObservationIgnored var onChange: (() -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        library = SceneLibrary.decode(library: defaults.data(forKey: Self.libraryKey), legacyScene: defaults.data(forKey: Self.legacyKey))
    }

    func select(_ id: UUID) { library.select(id) }
    func addScene() { library.duplicateSelected() }
    func removeSelectedScene() { library.removeSelected() }
    func renameSelectedScene(to name: String) { library.rename(library.selectedID, to: name) }
}
