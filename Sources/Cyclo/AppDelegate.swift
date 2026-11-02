import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private lazy var controller = StageController(preferences: preferences)
    private var menuBar: MenuBarController?
    private var hotKey: HotKey?
    private lazy var settings = SettingsWindowController(preferences: preferences)
    private let onboarding = OnboardingWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A journal left on disk means the last stage never exited cleanly (crash, force quit, power loss).
        controller.recoverIfNeeded()

        menuBar = MenuBarController(controller: controller, preferences: preferences,
                                    openSettings: { [weak self] in self?.settings.show() },
                                    openGuide: { [weak self] in self?.onboarding.show() })
        if !OnboardingWindowController.isDone { onboarding.show() }
        preferences.onChange = { [weak self] in self?.controller.preferencesChanged() }

        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey | cmdKey)) { [weak self] in
            self?.controller.toggle()
        }
        if hotKey == nil { NSLog("Cyclo: could not register ⌃⌥⌘S; it may be taken by another app") }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.exit(waiting: true)
    }
}
