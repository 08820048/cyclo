import Foundation
import Observation
import CycloCore

@MainActor
@Observable
final class Preferences {
    static let shared = Preferences()
    private static let key = "scene"

    var scene: SceneConfig {
        didSet {
            guard scene != oldValue else { return }
            UserDefaults.standard.set(scene.encoded(), forKey: Self.key)
            onChange?()
        }
    }

    @ObservationIgnored var onChange: (() -> Void)?

    private init() {
        scene = SceneConfig.decode(UserDefaults.standard.data(forKey: Self.key))
    }
}
