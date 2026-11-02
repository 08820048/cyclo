import AppKit
import SwiftUI

/// The welcome window shown on first launch, and again from the menu.
@MainActor
final class OnboardingWindowController {
    private static let doneKey = "onboardingDone"
    private var window: NSWindow?

    static var isDone: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    func show() {
        if window == nil {
            // Shown once, however it is dismissed; the menu has "使用引导…" for later.
            UserDefaults.standard.set(true, forKey: Self.doneKey)
            let view = OnboardingView { [weak self] in self?.window?.close() }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "欢迎使用 Cyclo"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        // Right after launch activation can lose to the app in front; the welcome window must still show.
        window?.orderFrontRegardless()
    }
}

private struct OnboardingView: View {
    let finish: () -> Void
    @State private var trusted = WindowSizer.isTrusted

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cyclo").font(.title.bold())
                    Text("一键把 Mac 变成干净的录屏舞台,用完一键恢复。").foregroundStyle(.secondary)
                }
            }

            step("1", "进入和退出", "按 ⌃⌥⌘S 进入,再按一次退出。进入后假菜单栏会盖住 Cyclo 的图标,也可以在它上面右键,或按住 ⌥ 点击来退出。") {
                EmptyView()
            }

            step("2", "允许辅助功能", "用来把窗口调到精确尺寸,并在假菜单栏里显示 App 的菜单。不授权也能用其余功能。") {
                if trusted {
                    Label("已授权", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Button("去授权") { WindowSizer.requestTrust() }
                }
            }

            step("3", "勿扰(可选)", "系统没有开放勿扰的接口,所以要用“快捷指令”:建两个指令,用“设定专注模式”动作分别打开、关闭勿扰,再把名字填进 Cyclo 设置。") {
                Button("打开快捷指令") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app")) }
            }

            Text("放心:Cyclo 只是盖住桌面,不会移动或删除你的文件;就算 Cyclo 崩溃,下次启动也会自动还原。")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("开始使用", action: finish).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            trusted = WindowSizer.isTrusted
        }
    }

    private func step(_ number: String, _ title: String, _ detail: String, @ViewBuilder action: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.headline).frame(width: 26, height: 26)
                .background(Circle().fill(.quaternary))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                action()
            }
        }
    }
}
