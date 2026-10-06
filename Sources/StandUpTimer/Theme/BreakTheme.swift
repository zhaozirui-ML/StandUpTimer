import AppKit
import SwiftUI

/// 主题 id，同时也是将来写进设置的取值，改名前要考虑旧值迁移
enum BreakThemeID: String, CaseIterable, Sendable {
    case mist, morandi, waterLily, sunrise, blueHour, forest
}

/// 休息画面的一套配色。
/// 全系列共用同一套几何和运动（见 FlowMotion），主题只提供颜色，所以对比度只需按一个模型验收。
/// 色值出处和对比度实测见 BreakThemes.swift。
struct BreakTheme: Sendable {
    enum Appearance: Sendable { case light, dark }

    struct Blob: Sendable {
        let rgb: UInt32
        let alpha: Double
    }

    struct Stop: Sendable {
        let rgb: UInt32
        let alpha: Double
    }

    let id: BreakThemeID
    let name: String
    let appearance: Appearance
    /// 竖直底色渐变（自上而下），位置固定为 FlowMotion.baseLocations。
    /// start 是休息开始时的样子，end 是休息结束时；中间按进度交叉淡化
    let baseStart: [UInt32]
    let baseEnd: [UInt32]
    /// 3 个流动色块，依次对应 FlowMotion.slots
    var blobs: [Blob]
    /// 雾散：色块整体透明度乘 (1 − blobFade × 进度)。只有晨雾用
    var blobFade: Double = 0
    /// 光源的外圈光晕和光芯，stop 位置固定为 FlowMotion.lightLocations
    let halo: [Stop]
    let core: [Stop]
    let textPrimary: UInt32
    var textSecondary: UInt32
    /// 按钮悬停/按下时叠的底色，键帽填满后文字也反色成它。
    /// 深色主题取底色最暗的 stop（压暗），浅色主题是白色（提亮）
    let surface: UInt32

    /// 系统开了「增强对比度」：次要文字改用主文字色，去掉流动色块
    func adjusted(increaseContrast: Bool) -> BreakTheme {
        guard increaseContrast else { return self }
        var theme = self
        theme.textSecondary = textPrimary
        theme.blobs = blobs.map { Blob(rgb: $0.rgb, alpha: 0) }
        return theme
    }
}

// MARK: - SwiftUI 用的派生颜色

extension BreakTheme {
    var primary: Color { Color(hex: textPrimary) }
    var secondary: Color { Color(hex: textSecondary) }
    var surfaceColor: Color { Color(hex: surface) }

    /// 图标底板的投影：浅色底上用 AppIcon.svg 原版的粉紫投影，深色底上用比背景更深的底色
    var plateShadow: Color {
        switch appearance {
        case .light: SunrisePalette.plateShadow.opacity(0.35)
        case .dark: surfaceColor.opacity(0.45)
        }
    }
}

// MARK: - 全系列共用的几何与运动

/// 流动背景的「语法」：所有主题共用，坐标里的 1920 / 1080 都是舞台坐标（见 Stage）
enum FlowMotion {
    struct Slot {
        /// 中心，占屏宽 / 屏高的比例
        let x: Double
        let y: Double
        /// 半径，占屏高的比例
        let radius: Double
        /// 漂移幅度，占舞台宽（1920·s）的比例。按舞台而非屏宽算，超宽屏上不会变快
        let driftX: Double
        let driftY: Double
        /// 横向漂移周期（秒），纵向周期再乘 yPeriodRatio
        let period: Double
    }

    static let baseLocations: [Double] = [0, 0.5, 0.8, 0.9, 1]

    /// 三个周期互不成整数倍，轨迹不会同步闭合；纯正弦往返，没有回弹，也没有明暗脉动（否则像「加载中」）
    static let slots: [Slot] = [
        Slot(x: 0.18, y: 0.24, radius: 0.62, driftX: 0.06, driftY: 0.035, period: 47), // 左上
        Slot(x: 0.52, y: 0.86, radius: 0.58, driftX: 0.07, driftY: 0.015, period: 39), // 地平线，几乎只横向流动
        Slot(x: 0.84, y: 0.16, radius: 0.50, driftX: 0.05, driftY: 0.03, period: 31),  // 右上
    ]
    static let yPeriodRatio = 1.3

    /// 色块边缘的衰减：用 5 个 stop 近似 smoothstep，中心没有尖峰
    static let falloffLocations: [Double] = [0, 0.25, 0.5, 0.75, 1]
    static let falloffAlphas: [Double] = [1, 0.844, 0.5, 0.156, 0]

    static let lightLocations: [Double] = [0, 0.35, 0.7, 1]
    /// 光源：舞台 x=1720（倒计时末位数字下方），从屏幕底边以下升到舞台 y=970
    static let lightX: CGFloat = 1720
    static let lightStartY: CGFloat = 1300
    static let lightEndY: CGFloat = 970
    static let haloRadius: CGFloat = 576
    static let coreRadius: CGFloat = 180
    /// 光源整体透明度随进度从 0.4 升到 1
    static let lightOpacityStart = 0.4

    /// 胶囊按钮和键帽的描边：主文字色 × 0.7，6 套主题实测都 ≥3:1
    static let strokeOpacity = 0.7
    static let hoverOpacity = 0.2
    static let pressedOpacity = 0.32
    static let keyFillOpacity = 0.92
}

/// 一次休息用到的背景：主题 + 每次进场随机的流动相位（多块屏幕共用，画面一致）
struct BackdropScene: Sendable {
    let theme: BreakTheme
    /// 每个色块的横、纵相位（弧度）
    let phases: [(x: Double, y: Double)]

    static func random(theme: BreakTheme) -> BackdropScene {
        let phases = FlowMotion.slots.map { _ in
            (x: Double.random(in: 0..<(2 * .pi)), y: Double.random(in: 0..<(2 * .pi)))
        }
        return BackdropScene(theme: theme, phases: phases)
    }
}

extension CGColor {
    static func rgb(_ hex: UInt32, alpha: Double = 1) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}
