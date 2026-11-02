import AppKit
import CycloCore

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let controller: StageController
    private let preferences: Preferences
    private let openSettings: () -> Void
    private let openGuide: () -> Void

    init(controller: StageController, preferences: Preferences, openSettings: @escaping () -> Void, openGuide: @escaping () -> Void) {
        self.controller = controller
        self.preferences = preferences
        self.openSettings = openSettings
        self.openGuide = openGuide
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        controller.onChange = { [weak self] in self?.updateIcon() }
        updateIcon()
    }

    private func updateIcon() {
        item.button?.image = Self.glyph(active: controller.isActive)
        item.button?.toolTip = controller.isActive ? "Cyclo:舞台进行中" : "Cyclo"
    }

    /// The app icon's mark as an 18 pt template: viewfinder brackets around a stage.
    /// The stage is an outline when idle and lit (filled) while the stage is up.
    private static func glyph(active: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.set()

            // Brackets: a 12.5 x 9.5 box centred in the 18 pt canvas, 3.6 arms, 2.2 turns.
            let box = NSRect(x: 2.75, y: 4.25, width: 12.5, height: 9.5)
            let arm: CGFloat = 3.6, radius: CGFloat = 2.2
            let brackets = NSBezierPath()
            for (sx, sy) in [(1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)] as [(CGFloat, CGFloat)] {
                let cx = sx > 0 ? box.minX : box.maxX, cy = sy > 0 ? box.minY : box.maxY
                brackets.move(to: NSPoint(x: cx, y: cy + sy * arm))
                brackets.line(to: NSPoint(x: cx, y: cy + sy * radius))
                brackets.curve(to: NSPoint(x: cx + sx * radius, y: cy),
                               controlPoint1: NSPoint(x: cx, y: cy + sy * radius * 0.45),
                               controlPoint2: NSPoint(x: cx + sx * radius * 0.45, y: cy))
                brackets.line(to: NSPoint(x: cx + sx * arm, y: cy))
            }
            brackets.lineWidth = 1.5
            brackets.lineCapStyle = .round
            brackets.lineJoinStyle = .round
            brackets.stroke()

            let stage = NSRect(x: 6.1, y: 6.6, width: 5.8, height: 4.8)
            if active {
                NSBezierPath(roundedRect: stage, xRadius: 1.3, yRadius: 1.3).fill()
            } else {
                let outline = NSBezierPath(roundedRect: stage.insetBy(dx: 0.55, dy: 0.55), xRadius: 0.9, yRadius: 0.9)
                outline.lineWidth = 1.1
                outline.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Cyclo"
        return image
    }

    // Rebuilt every time it opens, so it always reflects the current state and settings.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let scene = preferences.scene

        let toggle = NSMenuItem(title: controller.isActive ? "退出舞台" : "进入舞台", action: #selector(toggleStage), keyEquivalent: "s")
        toggle.keyEquivalentModifierMask = [.control, .option, .command]
        toggle.target = self
        menu.addItem(toggle)

        for note in controller.notes {
            let noteItem = NSMenuItem(title: note, action: nil, keyEquivalent: "")
            noteItem.isEnabled = false
            menu.addItem(noteItem)
        }
        menu.addItem(.separator())

        let scenes = NSMenu()
        let library = preferences.library
        for (index, entry) in library.scenes.enumerated() {
            let number = index + 1
            let sceneItem = NSMenuItem(title: entry.name, action: #selector(chooseScene(_:)), keyEquivalent: number <= SceneLibrary.shortcutCount ? "\(number)" : "")
            sceneItem.keyEquivalentModifierMask = [.control, .option, .command]
            sceneItem.target = self
            sceneItem.representedObject = entry.id
            sceneItem.state = entry.id == library.selectedID ? .on : .off
            scenes.addItem(sceneItem)
        }
        addSubmenu("场景:\(library.selected.name)", scenes, to: menu)

        let sizes = NSMenu()
        let resize = NSMenuItem(title: "调整目标窗口", action: #selector(toggleResize), keyEquivalent: "")
        resize.target = self
        resize.state = scene.resizeWindow ? .on : .off
        sizes.addItem(resize)
        sizes.addItem(.separator())
        var presets = WindowPreset.builtins
        if !presets.contains(scene.windowPreset) { presets.append(scene.windowPreset) }
        for preset in presets {
            let presetItem = NSMenuItem(title: preset.description, action: #selector(choosePreset(_:)), keyEquivalent: "")
            presetItem.target = self
            presetItem.representedObject = preset
            presetItem.state = preset == scene.windowPreset ? .on : .off
            sizes.addItem(presetItem)
        }
        addSubmenu("窗口规格", sizes, to: menu)

        let backdrops = NSMenu()
        for preset in GradientPreset.allCases {
            let gradientItem = NSMenuItem(title: preset.title, action: #selector(chooseGradient(_:)), keyEquivalent: "")
            gradientItem.target = self
            gradientItem.representedObject = preset.rawValue
            gradientItem.state = scene.backdrop == .gradient(preset) ? .on : .off
            backdrops.addItem(gradientItem)
        }
        backdrops.addItem(.separator())
        let custom = NSMenuItem(title: "纯色或图片…", action: #selector(showSettings), keyEquivalent: "")
        custom.target = self
        if case .gradient = scene.backdrop {} else { custom.state = .on }
        backdrops.addItem(custom)
        addSubmenu("背景", backdrops, to: menu)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let guide = NSMenuItem(title: "使用引导…", action: #selector(showGuide), keyEquivalent: "")
        guide.target = self
        menu.addItem(guide)
        menu.addItem(NSMenuItem(title: "退出 Cyclo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func addSubmenu(_ title: String, _ submenu: NSMenu, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }

    @objc private func toggleStage() { controller.toggle() }
    @objc private func toggleResize() { preferences.scene.resizeWindow.toggle() }
    @objc private func showSettings() { openSettings() }
    @objc private func chooseScene(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        controller.switchScene(to: id)
    }

    @objc private func showGuide() { openGuide() }

    @objc private func choosePreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? WindowPreset else { return }
        preferences.scene.windowPreset = preset
        preferences.scene.resizeWindow = true
    }

    @objc private func chooseGradient(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let preset = GradientPreset(rawValue: raw) else { return }
        preferences.scene.backdrop = .gradient(preset)
    }
}
