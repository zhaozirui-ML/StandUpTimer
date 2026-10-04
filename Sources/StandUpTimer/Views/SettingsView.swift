import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKeys.workMinutes) private var workMinutes = 25
    @AppStorage(SettingsKeys.shortBreakMinutes) private var shortBreakMinutes = 5
    @AppStorage(SettingsKeys.longBreakMinutes) private var longBreakMinutes = 20
    @AppStorage(SettingsKeys.longBreakEvery) private var longBreakEvery = 4
    @AppStorage(SettingsKeys.soundEnabled) private var soundEnabled = true
    @AppStorage(SettingsKeys.soundName) private var soundName = "Glass"
    @AppStorage(SettingsKeys.launchAtLogin) private var launchAtLogin = false

    @State private var loginItemError: String?
    private let sounds = SoundPlayer.availableSounds()

    var body: some View {
        Form {
            Section {
                stepperRow("工作时长", value: $workMinutes, in: 1...120,
                           display: "\(workMinutes) 分钟")
                stepperRow("站立休息", value: $shortBreakMinutes, in: 1...30,
                           display: "\(shortBreakMinutes) 分钟")
                stepperRow("长休息", value: $longBreakMinutes, in: 5...60, step: 5,
                           display: "\(longBreakMinutes) 分钟")
                stepperRow("长休息间隔", value: $longBreakEvery, in: 2...8,
                           display: "每 \(longBreakEvery) 个番茄")
            } header: {
                Text("时间设置")
            } footer: {
                Text("修改在下一阶段开始时生效")
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

    /// macOS 惯例：左侧只放名称，数值和 Stepper 一起靠右；数值用等宽数字，增减时宽度不跳
    private func stepperRow(_ title: String, value: Binding<Int>, in range: ClosedRange<Int>,
                            step: Int = 1, display: String) -> some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                Text(display).monospacedDigit()
                // 标签隐藏但保留，供 VoiceOver 读出
                Stepper(title, value: value, in: range, step: step).labelsHidden()
            }
        }
    }
}
