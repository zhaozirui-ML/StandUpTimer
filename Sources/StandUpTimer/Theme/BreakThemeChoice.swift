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
    /// 系统是深色外观时，白天也只用深色主题，避免整屏浅色晃眼。
    /// 浅色从 07:00 开始，冬天 6 点多天还没亮
    static func autoTheme(at date: Date, isDark: Bool) -> BreakThemeID {
        switch Calendar.current.component(.hour, from: date) {
        case 7..<12: isDark ? .blueHour : .mist
        case 12..<17: isDark ? .forest : .morandi
        case 17..<20: .waterLily
        default: .sunrise
        }
    }

    /// 当前系统外观是否为深色
    @MainActor
    static var systemIsDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
