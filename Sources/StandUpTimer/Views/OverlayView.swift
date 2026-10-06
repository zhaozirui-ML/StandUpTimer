import SwiftUI

/// 图标相关的固定颜色，取自 packaging/AppIcon.svg，不随休息画面主题变化。
/// 休息画面的背景和文字颜色在 Theme/BreakThemes.swift。
enum SunrisePalette {
    // 图标线条渐变：冷色 = 坐着，暖色 = 站起来
    static let cold = Color(hex: 0x4F5BFF)
    static let rose = Color(hex: 0xFF5C8A)
    static let warm = Color(hex: 0xFFA24D)
    /// StandGlyph 直接放在深色背景上时的默认投影色
    static let night = Color(hex: 0x140B24)
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
    /// 本次休息的总时长，用来算光源升起的进度
    @Published var total: TimeInterval = 1
    @Published var isLongBreak = false
    /// 长按 Esc 跳过的进度 0...1
    @Published var skipProgress: Double = 0
    /// 本次休息的画面主题，休息开始时确定
    @Published var theme = BreakTheme.sunrise

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }
}

/// 休息遮罩的前景：文字、图标和操作。背景是下层的 FlowBackdropView，这里保持透明。
/// 进场淡入、退场淡出由 OverlayController 用窗口透明度统一处理。
struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    let postpone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 进场动画状态：椅子先在，人再站起来
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
            let stage = Stage(size: geo.size)
            stageContent(scale: stage.scale)
                .offset(x: stage.origin.x, y: stage.origin.y)
        }
        .ignoresSafeArea()
        .onAppear(perform: playEntrance)
    }

    /// 舞台坐标（1920×1080 基准）里的两栏排版。
    /// 左栏：图标 + 标题 + 副标题；右栏：倒计时 + 说明 + 操作。
    /// 标题第二行与倒计时共用基线 598，副标题与「后回到工作」共用基线 670。
    private func stageContent(scale s: CGFloat) -> some View {
        let theme = model.theme
        let title = model.isLongBreak ? ("长休息，", "好好放松") : ("站起来，", "活动一下")
        let subtitle = model.isLongBreak ? "离开屏幕，走一走，喝口水" : "离开屏幕，伸展身体，看看远处"

        return ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 1920 * s, height: 1080 * s)

            // 图标和标题贴近，组成一组（lockup）
            AppIconBadge(
                size: 120 * s, plateShadow: theme.plateShadow,
                shaft: shaft, arrow: arrow, head: head, warmth: warmth, tilt: tilt
            )
            .scaleEffect(badgeIn ? 1 : 0.9)
            .opacity(badgeIn ? 1 : 0)
            .offset(x: 140 * s, y: 228 * s)

            // 汉字左侧自带约 0.04em 的空白，左移 4 让字面和图标左缘对齐
            Text(title.0)
                .font(.system(size: 96 * s, weight: .semibold))
                .foregroundStyle(theme.primary)
                .pinnedToBaseline(x: 136 * s, y: 478 * s)
            Text(title.1)
                .font(.system(size: 96 * s, weight: .semibold))
                .foregroundStyle(theme.primary)
                .pinnedToBaseline(x: 136 * s, y: 598 * s)
            Text(subtitle)
                .font(.system(size: 34 * s))
                .foregroundStyle(theme.secondary)
                .pinnedToBaseline(x: 140 * s, y: 670 * s)

            // 272pt 时数字字面顶与标题字面顶齐平；「0」左侧约 0.034em 空白，左移 9 对齐下方文字
            Text(timeString)
                .font(.system(size: 272 * s, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.primary)
                .pinnedToBaseline(x: 1031 * s, y: 598 * s)
            Text("后回到工作")
                .font(.system(size: 34 * s))
                .foregroundStyle(theme.secondary)
                .pinnedToBaseline(x: 1040 * s, y: 670 * s)

            HStack(spacing: 40 * s) {
                Button(action: postpone) {
                    Text("推迟 5 分钟")
                        .font(.system(size: 28 * s, weight: .medium))
                        .padding(.horizontal, 30 * s)
                        .padding(.vertical, 13 * s)
                }
                .buttonStyle(GhostPillStyle(theme: theme, scale: s))
                // 遮罩窗口是 key window，按钮会默认画出系统焦点环
                .focusEffectDisabled()

                SkipHint(theme: theme, progress: model.skipProgress, scale: s)
            }
            .frame(height: 60 * s)
            .offset(x: 1040 * s, y: 754 * s)
        }
    }

    private func playEntrance() {
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

/// 左栏的 App 图标：浅粉底板 + 可逐笔动画的字形，与 AppIcon.svg 同构
private struct AppIconBadge: View {
    /// 底板边长
    var size: CGFloat
    /// 底板投影：浅色主题上底板和背景亮度接近，靠投影把它托起来
    var plateShadow: Color
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
            .shadow(color: plateShadow, radius: size / 6, y: size / 12)
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

/// 次要按钮：描边胶囊。悬停、按下时叠一层主题的 surface：
/// 深色主题是压暗，浅色主题是提亮，都让背景离文字色更远，对比度只升不降
private struct GhostPillStyle: ButtonStyle {
    var theme: BreakTheme
    var scale: CGFloat
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let fill = configuration.isPressed ? FlowMotion.pressedOpacity : hovering ? FlowMotion.hoverOpacity : 0
        return configuration.label
            .foregroundStyle(theme.primary)
            .background(Capsule().fill(theme.surfaceColor.opacity(fill)))
            // 描边：非文字元素对比度需要 ≥3:1
            .overlay(Capsule().strokeBorder(theme.primary.opacity(FlowMotion.strokeOpacity), lineWidth: max(1.5, 2 * scale)))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// 「长按 esc 跳过」提示；按住时键帽从左往右被填满，填到的部分文字反色
private struct SkipHint: View {
    var theme: BreakTheme
    var progress: Double
    var scale: CGFloat

    var body: some View {
        HStack(spacing: 12 * scale) {
            keyLabel(color: theme.primary)
                .overlay {
                    keyLabel(color: theme.surfaceColor)
                        .background(theme.primary.opacity(FlowMotion.keyFillOpacity))
                        .mask(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle().frame(width: geo.size.width * progress)
                            }
                        }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6 * scale)
                        .strokeBorder(theme.primary.opacity(FlowMotion.strokeOpacity), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6 * scale))
            Text(progress > 0 ? "继续按住…" : "长按跳过")
                .font(.system(size: 22 * scale))
                .foregroundStyle(theme.primary)
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
