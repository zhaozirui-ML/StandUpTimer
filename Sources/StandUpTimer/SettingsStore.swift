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
    var shortBreakMinutes: Int {
        get { defaults.integer(forKey: SettingsKeys.shortBreakMinutes) }
        set { defaults.set(newValue, forKey: SettingsKeys.shortBreakMinutes) }
    }
    var longBreakMinutes: Int { defaults.integer(forKey: SettingsKeys.longBreakMinutes) }
    var longBreakEvery: Int { max(1, defaults.integer(forKey: SettingsKeys.longBreakEvery)) }
    var soundEnabled: Bool { defaults.bool(forKey: SettingsKeys.soundEnabled) }
    var soundName: String { defaults.string(forKey: SettingsKeys.soundName) ?? "Glass" }
    var launchAtLogin: Bool { defaults.bool(forKey: SettingsKeys.launchAtLogin) }
}
