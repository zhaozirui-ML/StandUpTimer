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
            Section("时间设置（下一阶段生效）") {
                Stepper("工作时长：\(workMinutes) 分钟", value: $workMinutes, in: 1...120)
                Stepper("站立休息：\(shortBreakMinutes) 分钟", value: $shortBreakMinutes, in: 1...30)
                Stepper("长休息：\(longBreakMinutes) 分钟", value: $longBreakMinutes, in: 5...60, step: 5)
                Stepper("每 \(longBreakEvery) 个番茄后长休息", value: $longBreakEvery, in: 2...8)
            }

            Section("提示音") {
                Toggle("休息开始/结束时播放提示音", isOn: $soundEnabled)
                Picker("提示音", selection: $soundName) {
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
}
