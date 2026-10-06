import AppKit

/// 设置里的「休息画面」选项：自动，或固定某一套主题。
/// rawValue 就是存进 UserDefaults 的字符串："auto" 或主题 id，读到未知值时回落到自动
enum BreakThemeChoice: Hashable, Sendable, RawRepresentable, CaseIterable {
    case auto
    case fixed(BreakThemeID)

    init?(rawValue: String) {
        if rawValue == "auto" {
            self = .auto
        } else if let id = BreakThemeID(rawValue: rawValue) {
            self = .fixed(id)
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .auto: "auto"
        case .fixed(let id): id.rawValue
        }
    }

    static var allCases: [BreakThemeChoice] { [.auto] + BreakThemeID.allCases.map { .fixed($0) } }

    /// 本次休息用哪套主题。只在休息开始时调用一次，整段休息不变
    func resolve(at date: Date, isDark: Bool) -> BreakThemeID {
        switch self {
        case .fixed(let id): id
        case .auto: Self.autoTheme(at: date, isDark: isDark)
        }
    }

    /// 自动规则：按时段换，上午、下午、傍晚、夜里各一套；
    /// 系统是深色外观时，白天也只用深色主题，避免整屏浅色晃眼
    static func autoTheme(at date: Date, isDark: Bool) -> BreakThemeID {
        autoSequence(isDark: isDark)[periodIndex(at: date)]
    }

    /// 自动模式一天里的 4 套主题，顺序对应 periodNames
    static func autoSequence(isDark: Bool) -> [BreakThemeID] {
        isDark ? [.blueHour, .forest, .waterLily, .sunrise] : [.mist, .morandi, .waterLily, .sunrise]
    }

    static let periodNames = ["上午", "下午", "傍晚", "夜里"]

    /// 时段：07–12 上午、12–17 下午、17–20 傍晚、其余夜里。浅色从 07:00 开始，冬天 6 点多天还没亮
    static func periodIndex(at date: Date) -> Int {
        switch Calendar.current.component(.hour, from: date) {
        case 7..<12: 0
        case 12..<17: 1
        case 17..<20: 2
        default: 3
        }
    }

    /// 设置里显示的名字
    var title: String {
        switch self {
        case .auto: "自动"
        case .fixed(let id): BreakTheme.named(id).name
        }
    }

    /// 设置里悬停时的说明：这套主题在自动模式下负责哪个时段
    var helpText: String {
        switch self {
        case .auto:
            return "按时段自动切换：上午、下午、傍晚、夜里各一套"
        case .fixed(let id):
            let light = Self.autoSequence(isDark: false).firstIndex(of: id)
            let dark = Self.autoSequence(isDark: true).firstIndex(of: id)
            switch (light, dark) {
            case let (l?, d?) where l == d: return "自动模式下：\(Self.periodNames[l])"
            case let (l?, _): return "自动模式下：\(Self.periodNames[l])，浅色外观"
            case let (_, d?): return "自动模式下：\(Self.periodNames[d])，深色外观"
            default: return ""
            }
        }
    }

    /// 当前系统外观是否为深色
    @MainActor
    static var systemIsDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
