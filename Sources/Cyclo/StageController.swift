import AppKit
import ApplicationServices
import CycloCore

/// Enters and exits the stage. Every step that changes system state records how to undo itself
/// in the journal *before* making the change; exit undoes the steps in reverse order.
@MainActor
final class StageController {
    private(set) var isActive = false
    /// Why the last stage skipped something (no Accessibility permission, etc.), for the menu.
    private(set) var notes: [String] = []
    var onChange: (() -> Void)?

    private let preferences: Preferences
    private let store = JournalStore.default
    private let backdrop = BackdropWindows()
    private let menuBarCover = MenuBarCover()
    private let clickHighlighter = ClickHighlighter()
    private var journal: SessionJournal?
    private var stagedWindow: AXUIElement?
    private var askedForAccessibility = false

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func toggle() {
        isActive ? exit() : enter()
    }

    /// ⌃⌥⌘<number>: ends the stage if one is up, otherwise opens the scene at that position.
    func toggle(sceneNumber: Int) {
        if isActive { exit(); return }
        guard let scene = preferences.library.scene(forShortcut: sceneNumber) else { return }
        preferences.select(scene.id)
        enter()
    }

    /// Switches scene; a stage that is up is redone with the new scene.
    func switchScene(to id: UUID) {
        let wasActive = isActive
        if wasActive { exit() }
        preferences.select(id)
        if wasActive { enter() }
    }

    func enter() {
        guard !isActive else { return }
        let config = preferences.scene
        let me = ProcessInfo.processInfo.processIdentifier
        let target = NSWorkspace.shared.frontmostApplication.flatMap { $0.processIdentifier == me ? nil : $0 }
        notes = []

        var journal = SessionJournal(startedAt: Date(), targetBundleID: target?.bundleIdentifier, targetPID: target?.processIdentifier)
        func record(_ change: (inout SessionJournal) -> Void) {
            change(&journal)
            self.journal = journal
            do { try store.save(journal) } catch { NSLog("Cyclo: could not write the restore journal: \(error)") }
        }
        record { _ in }
        isActive = true

        backdrop.show(config.backdrop)

        if !config.focusOnShortcut.isEmpty {
            record { $0.focusOffShortcut = config.focusOffShortcut.isEmpty ? nil : config.focusOffShortcut }
            FocusShortcut.run(config.focusOnShortcut)
        }

        if config.hideOtherApps {
            let apps = AppHider.visibleApps(excluding: target)
            record { $0.hiddenApps = apps.map { HiddenApp(pid: $0.processIdentifier, bundleID: $0.bundleIdentifier) } }
            AppHider.hide(apps)
        }

        if config.hideDock, !DockController.autohide {
            record { $0.dockAutohideWas = false }
            if !DockController.setAutohide(true) { notes.append("未能隐藏 Dock:请在 系统设置 › 隐私与安全性 › 自动化 中允许 Cyclo 控制“系统事件”") }
        }

        if config.resizeWindow, let target, target.bundleIdentifier != "com.apple.finder" {
            if !WindowSizer.isTrusted {
                notes.append("未调整窗口:需要在 系统设置 › 隐私与安全性 › 辅助功能 中允许 Cyclo")
                if !askedForAccessibility { askedForAccessibility = true; WindowSizer.requestTrust() }
            } else if let window = WindowSizer.frontWindow(of: target.processIdentifier),
                      let snapshot = WindowSizer.snapshot(of: window, pid: target.processIdentifier) {
                record { $0.window = snapshot }
                stagedWindow = window
                if let accepted = WindowSizer.apply(config.windowPreset, to: window),
                   accepted != config.windowPreset.size {
                    notes.append("窗口实际尺寸 \(Int(accepted.width)) × \(Int(accepted.height))(屏幕放不下或 App 限制了尺寸)")
                }
            }
        }

        if config.keepOnlyFrontWindow, let target, target.bundleIdentifier != "com.apple.finder" {
            if !WindowSizer.isTrusted {
                notes.append("未最小化其他窗口:需要在 系统设置 › 隐私与安全性 › 辅助功能 中允许 Cyclo")
                if !askedForAccessibility { askedForAccessibility = true; WindowSizer.requestTrust() }
            } else if let front = stagedWindow ?? WindowSizer.frontWindow(of: target.processIdentifier) {
                let others = WindowSizer.otherWindows(of: target.processIdentifier, keeping: front)
                record { $0.minimizedWindows = others.map(\.record) }
                others.forEach { WindowSizer.minimize($0.element) }
            }
        }

        // Last, so the menus it reads are the target's, after everything else has settled.
        if config.cleanMenuBar, let target {
            menuBarCover.show(.init(appName: target.localizedName ?? "", menus: MenuBarCover.menuTitles(of: target.processIdentifier),
                                    backdrop: config.backdrop, fixedStatus: config.fixedStatus))
            if !WindowSizer.isTrusted { notes.append("菜单栏只显示了 App 名:授予辅助功能权限后才能显示完整菜单") }
        }

        // Created after the menu bar cover so its rings are drawn above it. It only overlays; nothing to restore.
        if config.highlightClicks { clickHighlighter.start() }

        target?.activate()
        onChange?()
    }

    /// `waiting` blocks until the exit Shortcut finishes; used when quitting, so it isn't killed with us.
    func exit(waiting: Bool = false) {
        guard isActive || journal != nil else { return }
        let target = journal?.targetPID.flatMap { NSRunningApplication(processIdentifier: $0) }
        if let journal { Self.restore(journal, window: stagedWindow, waiting: waiting) }
        clickHighlighter.stop()
        menuBarCover.hide()
        backdrop.hide()
        store.clear()
        journal = nil
        stagedWindow = nil
        isActive = false
        notes = []
        target?.activate()
        onChange?()
    }

    /// Undoes a stage left behind by a crash or force quit.
    func recoverIfNeeded() {
        guard let leftover = store.load() else { return }
        NSLog("Cyclo: restoring a stage from \(leftover.startedAt) that did not exit cleanly")
        Self.restore(leftover, window: nil, waiting: false)
        store.clear()
    }

    func preferencesChanged() {
        if isActive {
            let scene = preferences.scene
            backdrop.update(scene.backdrop)
            if menuBarCover.isShowing { menuBarCover.update(backdrop: scene.backdrop, fixedStatus: scene.fixedStatus) }
        }
        onChange?()
    }

    /// Reverse order of `enter`.
    private static func restore(_ journal: SessionJournal, window: AXUIElement?, waiting: Bool) {
        if !journal.minimizedWindows.isEmpty, WindowSizer.isTrusted { WindowSizer.unminimize(journal.minimizedWindows) }
        if let snapshot = journal.window, WindowSizer.isTrusted { WindowSizer.restore(snapshot, window: window) }
        if let was = journal.dockAutohideWas { DockController.setAutohide(was) }
        AppHider.unhide(journal.hiddenApps)
        if let name = journal.focusOffShortcut { FocusShortcut.run(name, wait: waiting) }
    }
}
