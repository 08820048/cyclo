import Foundation
import CycloCore

// Lightweight test runner, so checks don't depend on XCTest. Run with `swift run cyclo-checks`.

var failures = 0
var passed = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    if condition() { passed += 1 } else {
        failures += 1
        print("FAIL \(file):\(line) \(message)")
    }
}

// MARK: CycloColor

do {
    let c = CycloColor(hex: "#F5A47A")
    check(c?.hex == "#F5A47A", "hex round trip: \(String(describing: c?.hex))")
    check(CycloColor(hex: "00ff00")?.green == 1, "hex without #")
    check(CycloColor(hex: "#12345") == nil, "short hex rejected")
    check(CycloColor(hex: "zzzzzz") == nil, "non-hex rejected")
    check(CycloColor(red: 2, green: -1, blue: 0.5) == CycloColor(red: 1, green: 0, blue: 0.5), "components clamped")
    for g in GradientPreset.allCases { check(g.colors.count >= 2, "gradient \(g) has colors") }
}

// MARK: WindowPreset

do {
    check(WindowPreset(string: "1280x800") == WindowPreset(width: 1280, height: 800), "parse x")
    check(WindowPreset(string: "1920 × 1080") == WindowPreset(width: 1920, height: 1080), "parse ×")
    check(WindowPreset(string: "1440X900") == WindowPreset(width: 1440, height: 900), "parse X")
    check(WindowPreset(string: "1280") == nil, "one number rejected")
    check(WindowPreset(string: "10x10") == nil, "too small rejected")
    check(WindowPreset(string: "abc") == nil, "garbage rejected")
}

// MARK: SceneConfig

do {
    var config = SceneConfig()
    config.backdrop = .image(path: "/tmp/a.png")
    config.windowPreset = WindowPreset(width: 1280, height: 720)
    config.focusOnShortcut = "勿扰开"
    check(SceneConfig.decode(config.encoded()) == config, "config round trip")
    check(SceneConfig.decode(nil) == SceneConfig(), "nil data gives defaults")
    let partial = SceneConfig.decode(#"{"hideDock": false}"#.data(using: .utf8))
    check(partial.hideDock == false && partial.hideOtherApps == true && partial.backdrop == .default, "missing keys default")
    let badBackdrop = SceneConfig.decode(#"{"backdrop": {"nope": {}}, "resizeWindow": false}"#.data(using: .utf8))
    check(badBackdrop.backdrop == .default && badBackdrop.resizeWindow == false, "unknown backdrop falls back without losing other keys")
    check(SceneConfig.decode(SceneConfig().encoded()).backdrop == .gradient(.dusk), "solid/gradient encode")
}

// MARK: Geometry

do {
    check(Geometry.fitted(CGSize(width: 1440, height: 900), in: CGSize(width: 1512, height: 949)) == CGSize(width: 1440, height: 900), "fits unchanged")
    check(Geometry.fitted(CGSize(width: 1920, height: 1080), in: CGSize(width: 1512, height: 949)) == CGSize(width: 1512, height: 850), "scaled down by width")
    check(Geometry.fitted(CGSize(width: 1000, height: 2000), in: CGSize(width: 1500, height: 1000)) == CGSize(width: 500, height: 1000), "scaled down by height")

    let area = CGRect(x: 0, y: 0, width: 1512, height: 949)
    check(Geometry.centered(CGSize(width: 1440, height: 900), in: area) == CGRect(x: 36, y: 25, width: 1440, height: 900), "centered")

    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let visible = CGRect(x: 0, y: 70, width: 1512, height: 879)
    check(Geometry.stageArea(screenFrame: screen, visibleFrame: visible) == CGRect(x: 0, y: 0, width: 1512, height: 949), "stage area drops menu bar, keeps dock area")

    let rect = CGRect(x: 36, y: 25, width: 1440, height: 900)
    let ax = Geometry.axOrigin(of: rect, primaryHeight: 982)
    check(ax == CGPoint(x: 36, y: 57), "AX origin: \(ax)")
    check(Geometry.appKitRect(axOrigin: ax, size: rect.size, primaryHeight: 982) == rect, "AX ↔ AppKit round trip")
    // A secondary screen above the primary has negative AX y.
    let above = CGRect(x: 0, y: 982, width: 1920, height: 1080)
    check(Geometry.axOrigin(of: above, primaryHeight: 982).y == -1080, "screen above primary")
}

// MARK: JournalStore

do {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cyclo-checks-\(UUID().uuidString)")
    let store = JournalStore(url: dir.appendingPathComponent("nested/session.json"))
    check(store.load() == nil, "empty store loads nil")

    var journal = SessionJournal(startedAt: Date(timeIntervalSince1970: 1_800_000_000), targetBundleID: "com.apple.Safari", targetPID: 42)
    journal.hiddenApps = [HiddenApp(pid: 7, bundleID: "com.tinyspeck.slackmacgap"), HiddenApp(pid: 8, bundleID: nil)]
    journal.dockAutohideWas = false
    journal.window = WindowSnapshot(pid: 42, origin: CGPoint(x: 10, y: 40), size: CGSize(width: 800, height: 600))
    journal.focusOffShortcut = "勿扰关"
    do {
        try store.save(journal)
        check(store.load() == journal, "journal round trip")
    } catch {
        check(false, "save failed: \(error)")
    }
    store.clear()
    check(store.load() == nil, "cleared")
    try? FileManager.default.removeItem(at: dir)
}

print("\(passed) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
