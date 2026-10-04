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
            // 以 1920×1080 为基准等比缩放，和短片里的排版一致
            let s = min(w / 1920, h / 1080)
            let glyphSize = min(h * 0.66, w * 0.38)
            let glyphCenter = CGPoint(x: w * 0.69, y: h * 0.5)
            // 太阳在小人身后：小人中心在画布中心右侧 168/1024 处
            let sunX = glyphCenter.x + glyphSize * 168 / 1024

            ZStack(alignment: .topLeading) {
                SunriseBackdrop(
                    progress: 0.1 + 0.9 * model.progress,
                    sunX: sunX,
                    sunTopY: glyphCenter.y + glyphSize * 0.26,
                    animated: !reduceMotion
                )

                StandGlyph(size: glyphSize, shaft: shaft, arrow: arrow, head: head, warmth: warmth, tilt: tilt)
                    .position(glyphCenter)

                copy(scale: s)
                    .padding(.leading, w * 0.073)
                    .padding(.top, h * 0.23)
            }
            .opacity(appeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear(perform: playEntrance)
    }

    private func copy(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.isLongBreak ? "长休息，\n好好放松" : "站起来，\n活动一下")
                .font(.system(size: 128 * s, weight: .semibold))
                .lineSpacing(10 * s)
                .foregroundStyle(SunrisePalette.cream)

            Text(model.isLongBreak ? "离开屏幕，走一走，喝口水" : "离开屏幕，伸展身体，看看远处")
                .font(.system(size: 36 * s))
                .foregroundStyle(SunrisePalette.moonlight)
                .padding(.top, 32 * s)

            HStack(alignment: .firstTextBaseline, spacing: 22 * s) {
                Text(timeString)
                    .font(.system(size: 92 * s, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(SunrisePalette.cream)
                Text("后回到工作")
                    .font(.system(size: 29 * s))
                    .foregroundStyle(SunrisePalette.moonlight)
            }
            .padding(.top, 46 * s)

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
            .padding(.top, 150 * s)
        }
    }

    private func playEntrance() {
        withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        guard !reduceMotion else {
            shaft = 1; arrow = 1; head = 1; warmth = 1; tilt = -7
            return
        }
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
    var sunTopY: CGFloat
    var animated: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r = max(w, h) * 0.3
            let sunY = h + r * 0.55 + (sunTopY - h - r * 0.55) * progress

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

/// 次要按钮：描边胶囊，悬停时轻微填充
private struct GhostPillStyle: ButtonStyle {
    var scale: CGFloat
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(SunrisePalette.cream)
            .background(
                Capsule().fill(SunrisePalette.cream.opacity(configuration.isPressed ? 0.2 : hovering ? 0.12 : 0))
            )
            .overlay(Capsule().strokeBorder(SunrisePalette.cream.opacity(0.4), lineWidth: max(1.5, 2 * scale)))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// 「长按 esc 跳过」提示；按住时键帽被进度填满
private struct SkipHint: View {
    var progress: Double
    var scale: CGFloat

    var body: some View {
        HStack(spacing: 12 * scale) {
            Text("esc")
                .font(.system(size: 18 * scale, weight: .medium))
                .foregroundStyle(progress > 0 ? SunrisePalette.cream : SunrisePalette.moonlight)
                .padding(.horizontal, 9 * scale)
                .padding(.vertical, 3 * scale)
                .background(alignment: .leading) {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 6 * scale)
                            .fill(SunrisePalette.cream.opacity(0.35))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 6 * scale).strokeBorder(SunrisePalette.moonlight, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 6 * scale))
            Text(progress > 0 ? "继续按住…" : "长按跳过")
                .font(.system(size: 22 * scale))
                .foregroundStyle(SunrisePalette.moonlight)
        }
    }
}
