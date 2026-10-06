import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKeys.workMinutes) private var workMinutes = 25
    @AppStorage(SettingsKeys.shortBreakMinutes) private var shortBreakMinutes = 5
    @AppStorage(SettingsKeys.longBreakMinutes) private var longBreakMinutes = 20
    @AppStorage(SettingsKeys.longBreakEvery) private var longBreakEvery = 4
    @AppStorage(SettingsKeys.soundEnabled) private var soundEnabled = true
    @AppStorage(SettingsKeys.soundName) private var soundName = "Glass"
    @AppStorage(SettingsKeys.launchAtLogin) private var launchAtLogin = false
    @AppStorage(SettingsKeys.breakTheme) private var breakTheme: BreakThemeChoice = .auto

    /// 「预览」按钮：传入此刻会用到的主题，由 AppDelegate 交给遮罩全屏试播
    var onPreview: (BreakThemeID) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme
    @State private var loginItemError: String?
    private let sounds = SoundPlayer.availableSounds()

    var body: some View {
        Form {
            Section {
                choicePicker("工作时长", selection: $workMinutes,
                             choices: SettingsChoices.workMinutes) { "\($0) 分钟" }
                choicePicker("站立休息", selection: $shortBreakMinutes,
                             choices: SettingsChoices.shortBreakMinutes) { "\($0) 分钟" }
                choicePicker("长休息", selection: $longBreakMinutes,
                             choices: SettingsChoices.longBreakMinutes) { "\($0) 分钟" }
                choicePicker("长休息间隔", selection: $longBreakEvery,
                             choices: SettingsChoices.longBreakEvery) { "每 \($0) 个番茄" }
            } header: {
                Text("时间设置")
            } footer: {
                Text("修改在下一阶段开始时生效")
            }

            // 画面（视觉）和提示音（听觉）挨着放，都属于休息时的感受
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                    ForEach(BreakThemeChoice.allCases, id: \.self) { choice in
                        ThemeTile(choice: choice, isSelected: breakTheme == choice) { breakTheme = choice }
                    }
                }
                .padding(.vertical, 4)
                // 缩略图看不出流动和整屏亮度，预览是选主题前唯一能「试穿」的办法
                HStack {
                    Text("全屏试播 8 秒，按 esc 或点击退出")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("预览") {
                        onPreview(breakTheme.resolve(at: Date(), isDark: colorScheme == .dark))
                    }
                }
            } header: {
                Text("休息画面")
            } footer: {
                // 每分钟刷新一次：设置窗口一直开着时，跨过时段边界说明也不会过期
                TimelineView(.everyMinute) { context in
                    Text(themeFooter(at: context.date))
                }
            }

            Section("提示音") {
                Toggle("休息开始/结束时播放提示音", isOn: $soundEnabled)
                Picker("声音", selection: $soundName) {
                    ForEach(sounds, id: \.self) { Text($0).tag($0) }
                }
                .disabled(!soundEnabled)
            }

            Section("通用") {
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .disabled(!LoginItemManager.isAvailable)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            try LoginItemManager.setEnabled(newValue)
                            loginItemError = nil
                        } catch {
                            loginItemError = "设置失败：\(error.localizedDescription)"
                            launchAtLogin = !newValue
                        }
                    }
                if !LoginItemManager.isAvailable {
                    Text("开机自启动需要从打包后的 .app 运行（make run）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
        .onChange(of: soundName) { _, _ in
            if soundEnabled { NSSound(named: soundName)?.play() }
        }
    }

    /// 「休息画面」的说明：自动模式写清「为什么现在是这套」
    private func themeFooter(at date: Date) -> String {
        switch breakTheme {
        case .fixed:
            return "每次休息都显示「\(breakTheme.title)」。修改在下一次休息时生效"
        case .auto:
            let isDark = colorScheme == .dark
            let names = BreakThemeChoice.periodNames
            let period = names[BreakThemeChoice.periodIndex(at: date)]
            let current = BreakTheme.named(BreakThemeChoice.autoTheme(at: date, isDark: isDark)).name
            // 规则说明从同一张时段表生成：浅色外观逐个列出，深色外观只列出不同的时段
            let light = BreakThemeChoice.autoSequence(isDark: false)
            let dark = BreakThemeChoice.autoSequence(isDark: true)
            let lightText = zip(names, light).map { "\($0)\(BreakTheme.named($1).name)" }.joined(separator: "、")
            let darkText = zip(names, zip(light, dark))
                .filter { $1.0 != $1.1 }
                .map { "\($0)换成\(BreakTheme.named($1.1).name)" }
                .joined(separator: "、")
            return """
                现在是\(period)（\(isDark ? "深色" : "浅色")外观），休息时显示「\(current)」。
                \(lightText)；系统为深色外观时，\(darkText)。修改在下一次休息时生效
                """
        }
    }

    /// 预设值弹出菜单，和「声音」用同一种控件
    private func choicePicker(_ title: String, selection: Binding<Int>, choices: [Int],
                              label: @escaping (Int) -> String) -> some View {
        Picker(title, selection: selection) {
            ForEach(SettingsChoices.including(selection.wrappedValue, in: choices), id: \.self) {
                Text(label($0)).tag($0)
            }
        }
    }
}
