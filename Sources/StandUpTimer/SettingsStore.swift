import Foundation

enum SettingsKeys {
    static let workMinutes = "workMinutes"
    static let shortBreakMinutes = "shortBreakMinutes"
    static let longBreakMinutes = "longBreakMinutes"
    static let longBreakEvery = "longBreakEvery"
    static let soundEnabled = "soundEnabled"
    static let soundName = "soundName"
    static let launchAtLogin = "launchAtLogin"
}

/// 设置窗口和菜单栏共用的预设选项
enum SettingsChoices {
    static let workMinutes = [15, 20, 25, 30, 45, 60]
    static let shortBreakMinutes = [3, 5, 8, 10, 15, 20]
    static let longBreakMinutes = [10, 15, 20, 25, 30]
    static let longBreakEvery = [2, 3, 4, 5, 6]

    /// 当前值不在预设里时（旧版本里设过的任意值）插入并排序，避免选中项显示为空白
    static func including(_ current: Int, in choices: [Int]) -> [Int] {
        choices.contains(current) ? choices : (choices + [current]).sorted()
    }
}

@MainActor
final class SettingsStore {
    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            SettingsKeys.workMinutes: 25,
            SettingsKeys.shortBreakMinutes: 5,
            SettingsKeys.longBreakMinutes: 20,
            SettingsKeys.longBreakEvery: 4,
            SettingsKeys.soundEnabled: true,
            SettingsKeys.soundName: "Glass",
            SettingsKeys.launchAtLogin: false,
        ])
    }

    var workMinutes: Int { defaults.integer(forKey: SettingsKeys.workMinutes) }
    var shortBreakMinutes: Int { defaults.integer(forKey: SettingsKeys.shortBreakMinutes) }
    var longBreakMinutes: Int { defaults.integer(forKey: SettingsKeys.longBreakMinutes) }
    var longBreakEvery: Int { max(1, defaults.integer(forKey: SettingsKeys.longBreakEvery)) }
    var soundEnabled: Bool { defaults.bool(forKey: SettingsKeys.soundEnabled) }
    var soundName: String { defaults.string(forKey: SettingsKeys.soundName) ?? "Glass" }
    var launchAtLogin: Bool { defaults.bool(forKey: SettingsKeys.launchAtLogin) }
}
