import SwiftUI

/// App 图标里的「椅子 + 箭头小人」字形，每一笔都能单独动画。
/// 坐标系与 packaging/AppIcon.svg 一致（1024 画布，已包含原图的 translate(30 0)）。
struct StandGlyph: View {
    /// 画布边长（pt）
    var size: CGFloat
    /// 身体从座面向上画出的进度：画的过程就是「站起来」
    var shaft: CGFloat = 1
    /// 箭头（肩膀）展开进度
    var arrow: CGFloat = 1
    /// 头部缩放
    var head: CGFloat = 1
    /// 0 = 全部冷色（坐着），1 = 图标原版渐变
    var warmth: Double = 1
    /// 椅子被推开时向后仰的角度
    var tilt: Double = 0

    private static let canvas: CGFloat = 1024
    private static let line: CGFloat = 76
    private static let outline: CGFloat = 118

    private var scale: CGFloat { size / Self.canvas }

    var body: some View {
        ZStack {
            // 白色贴纸描边 + 投影。图标原版的粉紫投影是给浅色底板用的，
            // 放在夜色背景上会变成一圈浅色光晕，这里改用比背景更深的夜色
            // compositingGroup：先把各笔画合成一个整体，再投影和调透明度，
            // 否则笔画重叠处（椅子转角）会出现两层叠加的色块
            strokes(paint: AnyShapeStyle(Color.white), width: Self.outline)
                .compositingGroup()
                .shadow(color: SunrisePalette.night.opacity(0.55), radius: 16 * scale, y: 14 * scale)
            // 冷色底层，渐变层随 warmth 淡入，实现由冷转暖
            strokes(paint: AnyShapeStyle(SunrisePalette.cold), width: Self.line)
            strokes(paint: AnyShapeStyle(gradient), width: Self.line)
                .compositingGroup()
                .opacity(warmth)
        }
        .frame(width: size, height: size)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: SunrisePalette.cold, location: 0),
                .init(color: SunrisePalette.rose, location: 0.55),
                .init(color: SunrisePalette.warm, location: 1),
            ],
            startPoint: Self.unit(310, 740),
            endPoint: Self.unit(790, 290)
        )
    }

    private func strokes(paint: AnyShapeStyle, width: CGFloat) -> some View {
        let style = StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round)
        let headR = width / 2
        return ZStack {
            Group {
                GlyphLine(points: [(270, 360), (340, 590), (320, 720)]).stroke(paint, style: style)
                GlyphLine(points: [(340, 590), (500, 590), (520, 720)]).stroke(paint, style: style)
            }
            .rotationEffect(.degrees(tilt), anchor: Self.unit(320, 720))
            GlyphLine(points: [(680, 720), (680, 440)]).trim(from: 0, to: shaft).stroke(paint, style: style)
            GlyphLine(points: [(680, 440), (605, 515)]).trim(from: 0, to: arrow).stroke(paint, style: style)
            GlyphLine(points: [(680, 440), (755, 515)]).trim(from: 0, to: arrow).stroke(paint, style: style)
            GlyphDot(cx: 680, cy: 318, r: headR)
                .fill(paint)
                .scaleEffect(head, anchor: Self.unit(680, 318))
        }
    }

    private static func unit(_ x: CGFloat, _ y: CGFloat) -> UnitPoint {
        UnitPoint(x: x / canvas, y: y / canvas)
    }
}

/// 1024 画布坐标的折线，按视图实际尺寸缩放
private struct GlyphLine: Shape {
    let points: [(CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
        let k = rect.width / 1024
        var path = Path()
        for (i, p) in points.enumerated() {
            let pt = CGPoint(x: rect.minX + p.0 * k, y: rect.minY + p.1 * k)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

private struct GlyphDot: Shape {
    let cx: CGFloat
    let cy: CGFloat
    let r: CGFloat

    func path(in rect: CGRect) -> Path {
        let k = rect.width / 1024
        return Path(ellipseIn: CGRect(x: rect.minX + (cx - r) * k, y: rect.minY + (cy - r) * k, width: 2 * r * k, height: 2 * r * k))
    }
}
