import CoreGraphics

/// 1920×1080 舞台：按 min(w/1920, h/1080) 等比缩放并在屏幕里居中。
/// 排版（OverlayView）和背景光源（FlowBackdropView）共用这一处公式，保证光源始终对准倒计时。
/// 16:10、超宽屏只多出背景，两栏不会被拉开。
struct Stage {
    let scale: CGFloat
    let origin: CGPoint

    init(size: CGSize) {
        scale = min(size.width / 1920, size.height / 1080)
        origin = CGPoint(x: (size.width - 1920 * scale) / 2, y: (size.height - 1080 * scale) / 2)
    }

    /// 舞台坐标转成屏幕坐标（左上原点）
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    }
}
