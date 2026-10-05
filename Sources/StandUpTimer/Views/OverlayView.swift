import SwiftUI

/// 「日出」遮罩的配色。项目还没有 design token 系统，
/// 这里的值全部取自 packaging/AppIcon.svg 与产品短片，只服务遮罩。
enum SunrisePalette {
    // 图标线条渐变：冷色 = 坐着，暖色 = 站起来
    static let cold = Color(hex: 0x4F5BFF)
    static let rose = Color(hex: 0xFF5C8A)
    static let warm = Color(hex: 0xFFA24D)
    // 夜色：休息刚开始时
    static let night = Color(hex: 0x140B24)
    static let dusk = Color(hex: 0x3A1640)
    // 黎明：休息快结束时
    static let dawnTop = Color(hex: 0x2B1239)
    static let dawnBottom = Color(hex: 0x7A2A4C)
    static let ember = Color(hex: 0xE8567E)
    static let glow = Color(hex: 0xFFC48A)
    // 文字
    static let cream = Color(hex: 0xFFF4EC)
    static let moonlight = Color(hex: 0xE4C3CF)
    // 图标底板与投影，取自 AppIcon.svg 的 bg 渐变和 feDropShadow
    static let plateTop = Color(hex: 0xF8E3EA)
    static let plateBottom = Color(hex: 0xEDC7D6)
    static let plateShadow = Color(hex: 0xB0567A)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

@MainActor
final class OverlayModel: ObservableObject {
    @Published var remaining: TimeInterval = 0
    /// 本次休息的总时长，用来算太阳升起的进度
    @Published var total: TimeInterval = 1
    @Published var isLongBreak = false
    /// 长按 Esc 跳过的进度 0...1
    @Published var skipProgress: Double = 0

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }
}

struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    let postpone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 进场动画状态：椅子先在，人再站起来
    @State private var appeared = false
    @State private var badgeIn = false
    @State private var shaft: CGFloat = 0
    @State private var arrow: CGFloat = 0
    @State private var head: CGFloat = 0
    @State private var warmth: Double = 0
    @State private var tilt: Double = 0

    private var timeString: String {
        let total = Int(model.remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // 以 1920×1080 为基准等比缩放。排版放在居中的 1920×1080 舞台里，
            // 16:10、超宽屏只多出背景，两栏不会被拉开；背景始终铺满整屏
            let s = min(w / 1920, h / 1080)
            let origin = CGPoint(x: (w - 1920 * s) / 2, y: (h - 1080 * s) / 2)

            ZStack(alignment: .topLeading) {
                // 太阳从倒计时末位数字下方升起，终点让日轮下缘被屏幕底边切掉，读作「正在升起」
                SunriseBackdrop(
                    progress: 0.1 + 0.9 * model.progress,
                    sunX: origin.x + 1720 * s,
                    sunEndY: origin.y + 970 * s,
                    radius: 576 * s,
                    animated: !reduceMotion
                )

                stage(scale: s)
                    .offset(x: origin.x, y: origin.y)
            }
            .opacity(appeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear(perform: playEntrance)
    }

    /// 舞台坐标（1920×1080 基准）里的两栏排版。
    /// 左栏：图标 + 标题 + 副标题；右栏：倒计时 + 说明 + 操作。
    /// 标题第二行与倒计时共用基线 598，副标题与「后回到工作」共用基线 670。
    private func stage(scale s: CGFloat) -> some View {
        let title = model.isLongBreak ? ("长休息，", "好好放松") : ("站起来，", "活动一下")
        let subtitle = model.isLongBreak ? "离开屏幕，走一走，喝口水" : "离开屏幕，伸展身体，看看远处"

        return ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 1920 * s, height: 1080 * s)

            // 图标和标题贴近，组成一组（lockup）
            AppIconBadge(size: 120 * s, shaft: shaft, arrow: arrow, head: head, warmth: warmth, tilt: tilt)
                .scaleEffect(badgeIn ? 1 : 0.9)
                .opacity(badgeIn ? 1 : 0)
                .offset(x: 140 * s, y: 228 * s)

            // 汉字左侧自带约 0.04em 的空白，左移 4 让字面和图标左缘对齐
            Text(title.0)
                .font(.system(size: 96 * s, weight: .semibold))
                .foregroundStyle(SunrisePalette.cream)
                .pinnedToBaseline(x: 136 * s, y: 478 * s)
            Text(title.1)
                .font(.system(size: 96 * s, weight: .semibold))
                .foregroundStyle(SunrisePalette.cream)
                .pinnedToBaseline(x: 136 * s, y: 598 * s)
            Text(subtitle)
                .font(.system(size: 34 * s))
                .foregroundStyle(SunrisePalette.moonlight)
                .pinnedToBaseline(x: 140 * s, y: 670 * s)

            // 272pt 时数字字面顶与标题字面顶齐平；「0」左侧约 0.034em 空白，左移 9 对齐下方文字
            Text(timeString)
                .font(.system(size: 272 * s, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(SunrisePalette.cream)
                .pinnedToBaseline(x: 1031 * s, y: 598 * s)
            Text("后回到工作")
                .font(.system(size: 34 * s))
                .foregroundStyle(SunrisePalette.moonlight)
                .pinnedToBaseline(x: 1040 * s, y: 670 * s)

            HStack(spacing: 40 * s) {
                Button(action: postpone) {
                    Text("推迟 5 分钟")
                        .font(.system(size: 28 * s, weight: .medium))
                        .padding(.horizontal, 30 * s)
                        .padding(.vertical, 13 * s)
                }
                .buttonStyle(GhostPillStyle(scale: s))
                // 遮罩窗口是 key window，按钮会默认画出系统焦点环
                .focusEffectDisabled()

                SkipHint(progress: model.skipProgress, scale: s)
            }
            .frame(height: 60 * s)
            .offset(x: 1040 * s, y: 754 * s)
        }
    }

    private func playEntrance() {
        withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        guard !reduceMotion else {
            badgeIn = true; shaft = 1; arrow = 1; head = 1; warmth = 1; tilt = -7
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { badgeIn = true }
        withAnimation(.easeOut(duration: 0.55).delay(0.45)) { shaft = 1 }
        withAnimation(.easeOut(duration: 0.35).delay(0.85)) { arrow = 1 }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(1.0)) { head = 1 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) { tilt = -7 }
        withAnimation(.easeInOut(duration: 1.4).delay(0.45)) { warmth = 1 }
    }
}

/// 夜色底 + 地平线暖光 + 随休息进度升起的太阳
private struct SunriseBackdrop: View {
    var progress: Double
    var sunX: CGFloat
    /// 休息结束时太阳中心的 y
    var sunEndY: CGFloat
    /// 太阳直径。跟舞台缩放走，超宽屏上不会被放大到压住文字
    var radius: CGFloat
    var animated: Bool

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let r = radius
            let sunY = h + r * 0.55 + (sunEndY - h - r * 0.55) * progress

            ZStack {
                LinearGradient(colors: [SunrisePalette.night, SunrisePalette.dusk], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [SunrisePalette.dawnTop, SunrisePalette.dawnBottom], startPoint: .top, endPoint: .bottom)
                    .opacity(progress)
                // 地平线的暖光
                LinearGradient(
                    colors: [SunrisePalette.ember.opacity(0.25 + progress * 0.55), SunrisePalette.ember.opacity(0)],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: h * 0.6)
                .frame(maxHeight: .infinity, alignment: .bottom)
                // 外圈柔光
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: 0xFFA46E).opacity(0.35 + progress * 0.25), location: 0),
                                .init(color: SunrisePalette.ember.opacity(0.18), location: 0.38),
                                .init(color: SunrisePalette.ember.opacity(0), location: 0.7),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: r * 1.6
                        )
                    )
                    .frame(width: r * 3.2, height: r * 3.2)
                    .position(x: sunX, y: sunY)
                // 太阳本体，边缘柔和
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: SunrisePalette.glow, location: 0),
                                .init(color: SunrisePalette.warm.opacity(0.85), location: 0.3),
                                .init(color: SunrisePalette.ember.opacity(0.45), location: 0.55),
                                .init(color: SunrisePalette.ember.opacity(0), location: 0.7),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: r / 2
                        )
                    )
                    .frame(width: r, height: r)
                    .position(x: sunX, y: sunY)
            }
            // 倒计时每秒刷新一次，用 1 秒线性动画把太阳的移动连成连续的上升
            .animation(animated ? .linear(duration: 1) : nil, value: progress)
        }
    }
}

/// 左栏的 App 图标：浅粉底板 + 可逐笔动画的字形，与 AppIcon.svg 同构
private struct AppIconBadge: View {
    /// 底板边长
    var size: CGFloat
    var shaft: CGFloat
    var arrow: CGFloat
    var head: CGFloat
    var warmth: Double
    var tilt: Double

    var body: some View {
        // AppIcon.svg 里底板 824、圆角 185，放在 1024 画布中央
        RoundedRectangle(cornerRadius: size * 185 / 824)
            .fill(LinearGradient(colors: [SunrisePalette.plateTop, SunrisePalette.plateBottom], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .shadow(color: SunrisePalette.night.opacity(0.45), radius: size / 6, y: size / 12)
            .overlay {
                StandGlyph(
                    size: size * 1024 / 824,
                    shaft: shaft, arrow: arrow, head: head, warmth: warmth, tilt: tilt,
                    shadowColor: SunrisePalette.plateShadow.opacity(0.35)
                )
            }
    }
}

private extension View {
    /// 把文字的首行基线钉在舞台坐标 (x, y)。
    /// 用零尺寸锚点 + overlay 定位，文字高度不参与布局，不会把舞台撑开
    func pinnedToBaseline(x: CGFloat, y: CGFloat) -> some View {
        Color.clear
            .frame(width: 0, height: 0)
            .overlay(alignment: .topLeading) {
                fixedSize().alignmentGuide(.top) { $0[.firstTextBaseline] }
            }
            .offset(x: x, y: y)
    }
}

/// 次要按钮：描边胶囊。休息末段背景被地平线照亮，悬停、按下改为压暗，保证文字对比度
private struct GhostPillStyle: ButtonStyle {
    var scale: CGFloat
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(SunrisePalette.cream)
            .background(
                Capsule().fill(SunrisePalette.night.opacity(configuration.isPressed ? 0.32 : hovering ? 0.2 : 0))
            )
            // 描边 0.7：非文字元素对比度需要 ≥3:1，0.4 只有约 2.1
            .overlay(Capsule().strokeBorder(SunrisePalette.cream.opacity(0.7), lineWidth: max(1.5, 2 * scale)))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// 「长按 esc 跳过」提示；按住时键帽从左往右被填满，填到的部分文字反色
/// 文字用 cream：这一行靠近地平线暖光，moonlight 在休息末段对比度不够
private struct SkipHint: View {
    var progress: Double
    var scale: CGFloat

    var body: some View {
        HStack(spacing: 12 * scale) {
            keyLabel(color: SunrisePalette.cream)
                .overlay {
                    keyLabel(color: SunrisePalette.night)
                        .background(SunrisePalette.cream.opacity(0.92))
                        .mask(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle().frame(width: geo.size.width * progress)
                            }
                        }
                }
                .overlay(RoundedRectangle(cornerRadius: 6 * scale).strokeBorder(SunrisePalette.moonlight, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 6 * scale))
            Text(progress > 0 ? "继续按住…" : "长按跳过")
                .font(.system(size: 22 * scale))
                .foregroundStyle(SunrisePalette.cream)
        }
    }

    private func keyLabel(color: Color) -> some View {
        Text("esc")
            .font(.system(size: 18 * scale, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 9 * scale)
            .padding(.vertical, 3 * scale)
    }
}
