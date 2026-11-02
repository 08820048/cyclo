import AppKit
import CycloCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController {
    private let preferences: Preferences
    private let openGuide: () -> Void
    private var window: NSWindow?

    init(preferences: Preferences, openGuide: @escaping () -> Void) {
        self.preferences = preferences
        self.openGuide = openGuide
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(preferences: preferences, openGuide: openGuide)))
            window.title = "Cyclo 设置"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()  // activation can lose to the app in front
    }
}

// MARK: Layout

/// A sidebar of pages in a window of fixed size: adding a setting grows a page's scroll area, never the window.
private enum Page: String, CaseIterable, Identifiable {
    case scenes = "场景", look = "外观", window = "窗口", environment = "环境", recording = "录屏辅助", general = "通用"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .scenes: "rectangle.stack"
        case .look: "paintpalette"
        case .window: "macwindow"
        case .environment: "sparkles"
        case .recording: "record.circle"
        case .general: "gearshape"
        }
    }

    /// Pages whose settings belong to the selected scene (as opposed to the app as a whole).
    var isPerScene: Bool { self != .scenes && self != .general }
}

struct SettingsView: View {
    @Bindable var preferences: Preferences
    let openGuide: () -> Void
    @State private var page: Page = .scenes

    var body: some View {
        HStack(spacing: 0) {
            List(Page.allCases, selection: $page) { page in
                Label(page.rawValue, systemImage: page.symbol).tag(page)
            }
            .listStyle(.sidebar)
            .frame(width: 168)

            Divider()

            VStack(spacing: 0) {
                if page.isPerScene { sceneBar }
                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 760, height: 520)
    }

    /// Everything on a per-scene page applies to one scene; this says which, and switches it.
    private var sceneBar: some View {
        HStack {
            Text("当前场景").foregroundStyle(.secondary)
            Picker("当前场景", selection: Binding(get: { preferences.library.selectedID }, set: { preferences.select($0) })) {
                ForEach(preferences.library.scenes) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
            .fixedSize()
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder private var detail: some View {
        switch page {
        case .scenes: ScenesPage(preferences: preferences)
        case .look: LookPage(preferences: preferences)
        case .window: WindowPage(preferences: preferences)
        case .environment: EnvironmentPage(preferences: preferences)
        case .recording: RecordingPage(preferences: preferences)
        case .general: GeneralPage(openGuide: openGuide)
        }
    }
}

private func sceneBinding(_ preferences: Preferences) -> Binding<SceneConfig> {
    Binding(get: { preferences.scene }, set: { preferences.scene = $0 })
}

// MARK: Pages

private struct ScenesPage: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Form {
            Section {
                ForEach(Array(preferences.library.scenes.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        preferences.select(entry.id)
                    } label: {
                        HStack {
                            Image(systemName: entry.id == preferences.library.selectedID ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(entry.id == preferences.library.selectedID ? Color.accentColor : .secondary)
                            Text(entry.name)
                            Spacer()
                            if index < SceneLibrary.shortcutCount { Text("⌃⌥⌘\(index + 1)").foregroundStyle(.secondary).monospacedDigit() }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("场景")
            } footer: {
                Text("每个场景是一套完整的设置。⌃⌥⌘1–9 直接进入对应序号的场景,舞台中再按一次退出。")
            }

            Section("选中的场景") {
                TextField("名称", text: Binding(get: { preferences.library.selected.name }, set: { preferences.renameSelectedScene(to: $0) }))
                HStack {
                    Button("复制为新场景") { preferences.addScene() }
                    Button("删除", role: .destructive) { preferences.removeSelectedScene() }
                        .disabled(preferences.library.scenes.count < 2)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private enum BackdropKind: String, CaseIterable, Identifiable {
    case gradient = "渐变", solid = "纯色", image = "图片"
    var id: String { rawValue }
}

private struct LookPage: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Form {
            Section("背景") {
                Picker("类型", selection: kind) {
                    ForEach(BackdropKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                backdropDetail
                BackdropView(backdrop: preferences.scene.backdrop)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Section {
                Toggle("干净菜单栏", isOn: sceneBinding(preferences).cleanMenuBar)
                Toggle("固定时间 9:41 与满电", isOn: sceneBinding(preferences).fixedStatus)
                    .disabled(!preferences.scene.cleanMenuBar)
            } header: {
                Text("菜单栏")
            } footer: {
                Text("盖一层假菜单栏,只显示目标 App 的菜单(需要辅助功能权限)。它会盖住 Cyclo 的图标:用 ⌃⌥⌘S 退出,或在假菜单栏上右键 / 按住 ⌥ 点击。")
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var backdropDetail: some View {
        switch preferences.scene.backdrop {
        case .gradient(let current):
            Picker("渐变", selection: Binding(get: { current }, set: { preferences.scene.backdrop = .gradient($0) })) {
                ForEach(GradientPreset.allCases) { Text($0.title).tag($0) }
            }
        case .solid(let color):
            ColorPicker("颜色", selection: Binding(get: { color.swiftUI }, set: { preferences.scene.backdrop = .solid(CycloColor($0)) }),
                        supportsOpacity: false)
        case .image(let path):
            HStack {
                Text(path.isEmpty ? "未选择" : (path as NSString).lastPathComponent)
                    .lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(path.isEmpty ? .secondary : .primary)
                Spacer()
                Button("选择图片…", action: chooseImage)
            }
        }
    }

    private var kind: Binding<BackdropKind> {
        Binding {
            switch preferences.scene.backdrop {
            case .gradient: .gradient
            case .solid: .solid
            case .image: .image
            }
        } set: { newKind in
            switch newKind {
            case .gradient: preferences.scene.backdrop = .default
            case .solid: preferences.scene.backdrop = .solid(CycloColor(hex: "#1C1C1E")!)
            case .image: chooseImage()
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            preferences.scene.backdrop = .image(path: url.path)
        }
    }
}

private struct WindowPage: View {
    @Bindable var preferences: Preferences
    @State private var customSize = ""
    @State private var trusted = WindowSizer.isTrusted

    var body: some View {
        Form {
            Section {
                Toggle("调整目标窗口", isOn: sceneBinding(preferences).resizeWindow)
                Picker("规格", selection: sceneBinding(preferences).windowPreset) {
                    ForEach(presetChoices, id: \.self) { Text($0.description).tag($0) }
                }
                .disabled(!preferences.scene.resizeWindow)
                HStack {
                    TextField("自定义,如 1366x768", text: $customSize)
                        .onSubmit(applyCustomSize)
                    Button("使用", action: applyCustomSize)
                        .disabled(WindowPreset(string: customSize) == nil)
                }
                .disabled(!preferences.scene.resizeWindow)
            } header: {
                Text("窗口规格")
            } footer: {
                Text("单位为点。Retina 屏上像素是两倍,例如 1440 × 900 点截出来是 2880 × 1800 像素。")
            }

            Section {
                Toggle("只保留前台窗口", isOn: sceneBinding(preferences).keepOnlyFrontWindow)
            } header: {
                Text("其他窗口")
            } footer: {
                Text("把目标 App 的其他窗口最小化,退出时恢复。")
            }

            if !trusted {
                Section {
                    HStack {
                        Text("调整窗口需要辅助功能权限").foregroundStyle(.secondary)
                        Spacer()
                        Button("去授权") { WindowSizer.requestTrust() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            trusted = WindowSizer.isTrusted
        }
    }

    private var presetChoices: [WindowPreset] {
        var presets = WindowPreset.builtins
        if !presets.contains(preferences.scene.windowPreset) { presets.append(preferences.scene.windowPreset) }
        return presets
    }

    private func applyCustomSize() {
        guard let preset = WindowPreset(string: customSize) else { return }
        preferences.scene.windowPreset = preset
        customSize = ""
    }
}

private struct EnvironmentPage: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Form {
            Section("清理") {
                Toggle("隐藏其他 App", isOn: sceneBinding(preferences).hideOtherApps)
                Toggle("自动隐藏 Dock", isOn: sceneBinding(preferences).hideDock)
            }

            Section {
                TextField("进入时运行", text: sceneBinding(preferences).focusOnShortcut, prompt: Text("快捷指令名称,如“打开勿扰”"))
                TextField("退出时运行", text: sceneBinding(preferences).focusOffShortcut, prompt: Text("快捷指令名称,如“关闭勿扰”"))
            } header: {
                Text("勿扰模式")
            } footer: {
                Text("在“快捷指令”App 中用“设定专注模式”动作建两个指令,分别打开、关闭勿扰,把名字填在这里。留空则跳过。")
            }
        }
        .formStyle(.grouped)
    }
}

private struct RecordingPage: View {
    @Bindable var preferences: Preferences
    @State private var inputAllowed = KeyDisplay.hasPermission

    var body: some View {
        Form {
            Section {
                Toggle("高亮鼠标点击", isOn: sceneBinding(preferences).highlightClicks)
            } header: {
                Text("鼠标")
            } footer: {
                Text("点击处出现一圈光环,不影响点击。")
            }

            Section {
                Toggle("显示按键", isOn: sceneBinding(preferences).showKeys)
                Toggle("同时显示普通输入", isOn: sceneBinding(preferences).showTypedKeys)
                    .disabled(!preferences.scene.showKeys)
                if preferences.scene.showKeys, !inputAllowed {
                    HStack {
                        Text("需要“输入监控”权限").foregroundStyle(.secondary)
                        Spacer()
                        Button("去授权") { KeyDisplay.requestPermission() }
                    }
                }
            } header: {
                Text("键盘")
            } footer: {
                Text("默认只显示快捷键(如 ⌘C)和 esc、方向键等。打开“普通输入”后,打字也会显示,录屏时可能录到密码或私信,请留意。授权后需要重新进入舞台。")
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            inputAllowed = KeyDisplay.hasPermission
        }
    }
}

private struct GeneralPage: View {
    let openGuide: () -> Void
    @State private var accessibility = WindowSizer.isTrusted
    @State private var input = KeyDisplay.hasPermission

    var body: some View {
        Form {
            Section("快捷键") {
                LabeledContent("进入 / 退出当前场景", value: "⌃⌥⌘S")
                LabeledContent("进入 / 退出第 N 个场景", value: "⌃⌥⌘1–9")
            }

            Section("权限") {
                permission("辅助功能", detail: "调整窗口、最小化其他窗口、读取菜单", granted: accessibility) { WindowSizer.requestTrust() }
                permission("输入监控", detail: "显示按键", granted: input) { KeyDisplay.requestPermission() }
            }

            Section {
                Button("查看使用引导…", action: openGuide)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibility = WindowSizer.isTrusted
            input = KeyDisplay.hasPermission
        }
    }

    private func permission(_ name: String, detail: String, granted: Bool, request: @escaping () -> Void) -> some View {
        LabeledContent {
            if granted {
                Label("已授权", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("去授权", action: request)
            }
        } label: {
            VStack(alignment: .leading) {
                Text(name)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
