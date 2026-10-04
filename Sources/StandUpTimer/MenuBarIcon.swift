import AppKit

/// 菜单栏用的单色字形（template image）：系统会按菜单栏深浅色和选中状态自动上色。
/// 笔画坐标与 packaging/AppIcon.svg、Views/StandGlyph.swift 一致（1024 画布）。
@MainActor
enum MenuBarIcon {
    /// 工作中：椅子 + 小人
    static let full = make(standingOnly: false)
    /// 休息中：只剩站着的小人
    static let standing = make(standingOnly: true)

    private static let chair: [[CGPoint]] = [
        [CGPoint(x: 270, y: 360), CGPoint(x: 340, y: 590), CGPoint(x: 320, y: 720)],
        [CGPoint(x: 340, y: 590), CGPoint(x: 500, y: 590), CGPoint(x: 520, y: 720)],
    ]
    private static let person: [[CGPoint]] = [
        [CGPoint(x: 680, y: 720), CGPoint(x: 680, y: 440)],
        [CGPoint(x: 605, y: 515), CGPoint(x: 680, y: 440), CGPoint(x: 755, y: 515)],
    ]
    private static let head = CGPoint(x: 680, y: 318)
    private static let line: CGFloat = 76

    private static func make(standingOnly: Bool) -> NSImage {
        let strokes = standingOnly ? person : chair + person
        // 只裁出笔画实际占用的区域（含线宽一半的圆头），图标在菜单栏里才不会显得小
        let pad = line / 2
        let xs = strokes.flatMap { $0.map(\.x) } + [head.x]
        let minX = xs.min()! - pad
        let maxX = xs.max()! + pad
        let minY = head.y - pad
        let maxY: CGFloat = 720 + pad
        // 菜单栏图标高度约 16pt
        let k = 16 / (maxY - minY)
        let size = NSSize(width: ((maxX - minX) * k).rounded(.up), height: 16)

        let image = NSImage(size: size, flipped: true) { _ in
            NSColor.black.set()
            func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - minX) * k, y: (p.y - minY) * k) }
            for stroke in strokes {
                let path = NSBezierPath()
                path.lineWidth = line * k
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: pt(stroke[0]))
                for p in stroke.dropFirst() { path.line(to: pt(p)) }
                path.stroke()
            }
            let r = pad * k
            let c = pt(head)
            NSBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "StandUpTimer"
        return image
    }
}
