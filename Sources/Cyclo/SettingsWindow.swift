import AppKit
import CycloCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController {
    private let preferences: Preferences
    private var window: NSWindow?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(preferences: preferences)))
            window.title = "Cyclo 设置"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

private enum BackdropKind: String, CaseIterable, Identifiable {
    case gradient = "渐变", solid = "纯色", image = "图片"
    var id: String { rawValue }
}

struct SettingsView: View {
    @Bindable var preferences: Preferences
    @State private var customSize = ""
    @State private var trusted = WindowSizer.isTrusted

    private var scene: Binding<SceneConfig> { $preferences.scene }

    var body: some View {
        Form {
            Section {
                Picker("场景", selection: Binding(get: { preferences.library.selectedID }, set: { preferences.select($0) })) {
                    ForEach(preferences.library.scenes) { entry in
                        Text(sceneTitle(entry)).tag(entry.id)
                    }
                }
                TextField("名称", text: Binding(get: { preferences.library.selected.name }, set: { preferences.renameSelectedScene(to: $0) }))
                HStack {
                    Button("复制为新场景") { preferences.addScene() }
                    Button("删除此场景", role: .destructive) { preferences.removeSelectedScene() }
                        .disabled(preferences.library.scenes.count < 2)
                }
            } header: {
                Text("场景")
            } footer: {
                Text("下面的所有设置都属于当前场景。⌃⌥⌘1–9 直接进入对应序号的场景,舞台中再按一次退出。")
                    .foregroundStyle(.secondary)
            }

            Section("背景") {
                Picker("类型", selection: kind) {
                    ForEach(BackdropKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                backdropDetail
                BackdropView(backdrop: preferences.scene.backdrop)
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Section("录屏辅助") {
                Toggle("高亮鼠标点击", isOn: scene.highlightClicks)
            }

            Section("清理") {
                Toggle("隐藏其他 App", isOn: scene.hideOtherApps)
                Toggle("自动隐藏 Dock", isOn: scene.hideDock)
            }

            Section {
                Toggle("干净菜单栏", isOn: scene.cleanMenuBar)
                Toggle("固定时间 9:41 与满电", isOn: scene.fixedStatus)
                    .disabled(!preferences.scene.cleanMenuBar)
            } header: {
                Text("菜单栏")
            } footer: {
                Text("盖一层假菜单栏,只显示目标 App 的菜单(需要辅助功能权限)。舞台中它会盖住 Cyclo 自己的图标,请用 ⌃⌥⌘S 退出。")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("只保留前台窗口", isOn: scene.keepOnlyFrontWindow)
                Toggle("调整目标窗口", isOn: scene.resizeWindow)
                Picker("规格", selection: scene.windowPreset) {
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
                if !trusted {
                    HStack {
                        Text("需要辅助功能权限才能调整窗口").foregroundStyle(.secondary)
                        Spacer()
                        Button("去授权") { WindowSizer.requestTrust() }
                    }
                }
            } header: {
                Text("窗口规格")
            } footer: {
                Text("单位为点。Retina 屏上像素是两倍,例如 1440 × 900 点截出来是 2880 × 1800 像素。")
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("进入时运行", text: scene.focusOnShortcut, prompt: Text("快捷指令名称,如“打开勿扰”"))
                TextField("退出时运行", text: scene.focusOffShortcut, prompt: Text("快捷指令名称,如“关闭勿扰”"))
            } header: {
                Text("勿扰模式")
            } footer: {
                Text("在“快捷指令”App 中用“设定专注模式”动作建两个指令,分别打开、关闭勿扰,把名字填在这里。留空则跳过。")
                    .foregroundStyle(.secondary)
            }

            Section("快捷键") {
                LabeledContent("进入 / 退出当前场景", value: "⌃⌥⌘S")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            trusted = WindowSizer.isTrusted
        }
    }

    private func sceneTitle(_ entry: NamedScene) -> String {
        preferences.library.shortcutNumber(of: entry.id).map { "\(entry.name)  ⌃⌥⌘\($0)" } ?? entry.name
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
