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
