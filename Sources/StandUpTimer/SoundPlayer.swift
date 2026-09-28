import AppKit

@MainActor
final class SoundPlayer {
    private let settings: SettingsStore
    private var current: NSSound?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func play() {
        guard settings.soundEnabled else { return }
        current?.stop()
        current = NSSound(named: settings.soundName)
        current?.play()
    }

    /// 枚举 /System/Library/Sounds 里的系统提示音名
    static func availableSounds() -> [String] {
        let dir = "/System/Library/Sounds"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        return names
            .filter { $0.hasSuffix(".aiff") }
            .map { ($0 as NSString).deletingPathExtension }
            .sorted()
    }
}
