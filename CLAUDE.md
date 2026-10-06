# StandUpTimer

macOS 菜单栏番茄钟 + 站立提醒工具。Swift 6 + AppKit，SwiftUI 只用于遮罩和设置窗口。无第三方依赖，只需 Command Line Tools，不需要 Xcode。

## 开发机

本机是唯一的主力开发机，改代码、推送、发 Release 都在这里做。

## 检查命令

这是 Swift 项目，全局规则里的 `pnpm typecheck` / `pnpm lint` 不适用，改用：

- `make build`：release 编译。Swift 6 严格并发检查也在这一步，相当于 typecheck。改完代码必须通过才能报告完成。
- 没有 linter，也没有测试 target。
- 涉及运行行为的改动，用 `make dev-fast`（1 配置分钟 = 1 真实秒）实际跑一遍。

## 代码结构

| 文件 | 职责 |
|---|---|
| `TimerEngine.swift` | 计时状态机（Phase：工作 / 短休 / 长休），基于墙钟 `phaseEndDate`，发出 `TimerEvent` |
| `StatusItemController.swift` | 菜单栏图标、倒计时文字（等宽数字）、下拉菜单 |
| `MenuBarIcon.swift` | 菜单栏的单色 template 字形：工作中为椅子 + 小人，休息中只剩小人 |
| `OverlayController.swift` | 休息时每块屏幕一个全屏遮罩窗口（流动背景 + 前景排版），淡入淡出；长按 Esc 1 秒跳过 |
| `Views/OverlayView.swift` | 遮罩前景：左栏图标 + 文案，右栏倒计时 + 操作，按 1920×1080 舞台排版 |
| `Views/FlowBackdropView.swift` | 遮罩背景：CAGradientLayer 层树（底色交叉淡化 + 3 个流动色块 + 光源），由 WindowServer 绘制 |
| `BackdropClock.swift` | 背景的步进时钟和能耗分档：接电源 10Hz、电池 5Hz；减弱动态效果、低电量、过热、离座时定格；被遮住时暂停 |
| `Theme/BreakTheme.swift` + `Theme/BreakThemes.swift` | 休息画面主题的数据结构、全系列共用的几何与运动（`FlowMotion`）、6 套主题色值 |
| `Views/Stage.swift` | 1920×1080 舞台的缩放公式，排版和背景光源共用 |
| `Views/StandGlyph.swift` | 图标里的「椅子 + 箭头小人」字形，坐标取自 `AppIcon.svg`，每笔可单独动画 |
| `Views/SettingsView.swift` | 设置窗口 |
| `SettingsStore.swift` | 设置读写，key 集中在 `SettingsKeys`，存在 `UserDefaults.standard` |
| `StatsStore.swift` | 每日统计，写入 `~/Library/Application Support/StandUpTimer/stats.json` |
| `LoginItemManager.swift` | 开机自启动（`SMAppService.mainApp`），只在 `.app` 包里运行时可用 |
| `SoundPlayer.swift` | 播放 `/System/Library/Sounds` 里的系统提示音 |
| `AppDelegate.swift` / `main.swift` | 启动入口，把各控制器连起来 |
| `packaging/` | `Info.plist`、图标 SVG / icns、SVG 转 PNG 的 `render.swift` |

## 必须保持的约束

- 所有控制器都是 `@MainActor`，Timer / 通知回调里用 `MainActor.assumeIsolated`。
- 剩余时间由 `phaseEndDate` 推算，1 Hz Timer 只负责刷新显示，不要改成逐秒累减（App Nap 会导致漂移）。
- 遮罩窗口不激活 App，以免打乱用户下层的窗口焦点。
- 流动背景由 `BackdropClock` 在主线程低频步进（每步一个 CATransaction），不要改成 Core Animation 自动动画或 TimelineView：那样 WindowServer 会按 60/120Hz 合成，耗电高出数倍。
- 以下改动属于数据结构变更，动手前先确认：`SettingsKeys` 里的 key 名、`DayStats` 字段、stats.json 路径、Bundle ID（UserDefaults 和开机自启动登记都跟着它走）。

## UI 样式

项目没有 design token 系统。休息画面的颜色按主题集中在 `Theme/BreakThemes.swift`（每个色值注释了出处，改色后要重新核对文字对比度）；图标本身的颜色在 `OverlayView.swift` 顶部的 `SunrisePalette`（取自 `AppIcon.svg`）。字号、间距以 1920×1080 为基准按屏幕等比缩放，写在 `OverlayView.swift` 里。设置窗口用系统默认样式。需要新值时先说明缺少 token，不要自己发明一套数值。

## 发版流程

1. `packaging/Info.plist`：`CFBundleShortVersionString` 改成新版本号，`CFBundleVersion` 加 1。
2. `make bundle`，确认构建和签名通过。
3. 提交并 `git push`。
4. 打包：`ditto -c -k --keepParent dist/StandUpTimer.app dist/StandUpTimer-<版本>.zip`。用 `ditto` 才能完整保留签名，zip 放在 `dist/`（已被 gitignore）。
5. 发布：`gh release create v<版本> dist/StandUpTimer-<版本>.zip --target main --title "StandUpTimer <版本>" --notes "..."`。
6. 更新本机：退出正在运行的 App，删除 `/Applications/StandUpTimer.app`，拷入新版，再 `open`。

改了 `packaging/AppIcon.svg` 后，先运行一次 `make icon` 重新生成 `AppIcon.icns`。

## 本地文件

`StandUpTimer.bundle`、`StandUpTimer-个人电脑操作步骤.md` 和 `promo/` 是本地文件，已写进 `.git/info/exclude`（只在本机生效），不要提交。`promo/` 是宣传短片的 Remotion 项目，有自己独立的本地 git 仓库（不推送），在它里面提交即可。
