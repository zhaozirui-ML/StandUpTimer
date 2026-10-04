# StandUpTimer

基于番茄工作法的 macOS 菜单栏站立提醒工具，防止久坐伤身。

- 🍅 经典番茄钟：25 分钟工作 / 5 分钟站立休息，每 4 个番茄后长休息 20 分钟（均可在设置中调整）
- 🌅 休息开始时「日出」遮罩覆盖所有屏幕和 Space：太阳随休息进度升起，倒计时结束自动回到工作；长按 Esc 1 秒可跳过休息（点击空白处不会误跳）
- ⏸ 支持暂停/继续、跳过当前阶段、推迟休息 5 分钟、重置当前倒计时
- ⚡ 菜单栏"站立休息时长"子菜单可快捷切换休息时长（下一次休息生效），完整设置在"设置…"窗口
- 📊 每日统计（番茄数 / 站立次数），存于 `~/Library/Application Support/StandUpTimer/stats.json`
- 🔔 休息开始/结束提示音（系统声音，可选）
- 🚀 可选开机自启动（设置中开启）
- 💤 睡眠感知：合盖超过 5 分钟视为已休息，唤醒后重新开始新番茄；短暂睡眠则原地恢复

## 构建与运行

只需要 Command Line Tools（Swift 6+），不需要 Xcode。

```sh
make run        # 构建 → 打包 dist/StandUpTimer.app → ad-hoc 签名 → 启动
make bundle     # 只打包不启动
make dev        # 开发模式：swift run 裸二进制（无 bundle，自启动不可用）
make dev-fast   # 加速调试：1 配置分钟 = 1 真实秒
make clean
```

想装到应用程序文件夹：`cp -R dist/StandUpTimer.app /Applications/`（注意：移动位置后需在设置中重新开关一次"开机自启动"）。

## 使用

启动后立即开始第一个 25 分钟番茄，菜单栏显示 App 字形加倒计时（如 `24:59`）；休息时字形只剩站着的小人，暂停时整体变灰。点击图标可暂停、跳过、推迟、查看今日统计、打开设置或退出。

调试加速：`STANDUP_TIMESCALE=300 ./.build/debug/StandUpTimer`（25 分钟 → 5 秒，菜单栏仍按配置时长显示）。

## 技术说明

- AppKit `NSStatusItem` + `NSMenu`，SwiftUI 只用于遮罩和设置窗口（`NSHostingView`）
- 计时基于墙钟 `phaseEndDate`，1 Hz Timer 仅重算剩余时间，App Nap 不会导致漂移
- 遮罩为每屏一个 `.screenSaver` 层级的无边框窗口，`canJoinAllSpaces + fullScreenAuxiliary` 覆盖全屏应用；不激活 App 以免打乱下层窗口
- 开机自启动用 `SMAppService.mainApp`，每次启动按用户偏好幂等重注册（应对重新构建后注册失效）
- Swift 6 严格并发：所有控制器 `@MainActor`，Timer/通知回调用 `MainActor.assumeIsolated`

## 许可证

[MIT](LICENSE)
