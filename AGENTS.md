# Cyclo

录屏/截图专属桌面:一键把 Mac 切换成干净的"舞台",用完一键恢复。macOS 26+ 菜单栏应用,AppKit + 少量 SwiftUI,SwiftPM 构建。

- 产品与技术文档在 `docs/`:`产品需求文档.md`、`技术方案.md`、`里程碑.md`。做完一项把 `里程碑.md` 里对应的 `- [ ]` 改成 `- [x]`。
- 构建 App:`scripts/build-app.sh [debug|release]` → `build/Cyclo.app`。SwiftUI 宏需要 Xcode 工具链,脚本会自动设置 `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`。
- 自检:`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift run cyclo-checks`(纯逻辑放 `CycloCore`,不依赖 AppKit,才能被自检覆盖)。
- 可逆是底线:任何改动系统状态的步骤,都必须**先**写恢复日志(`SessionJournal`)再改,并在 `StageController.exit` 和启动恢复里有对应还原。
- 不修改、不移动用户的桌面文件;不改 Finder 的 `CreateDesktop`。
