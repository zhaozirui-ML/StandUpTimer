import AppKit
import QuartzCore

/// 休息遮罩的流动背景：一棵 CAGradientLayer 层树，渐变由 WindowServer 直接绘制，
/// App 进程里不做任何光栅化。层树：两层竖直底色（交叉淡化）+ 3 个流动色块 + 光源（光晕 + 光芯）。
/// 本视图只负责「给定进度和时间，各层该在哪」；什么时候更新、多久更新一次由 BackdropClock 决定。
@MainActor
final class FlowBackdropView: NSView {
    let scene: BackdropScene

    private let baseStart = CAGradientLayer()
    private let baseEnd = CAGradientLayer()
    private let blobGroup = CALayer()
    private var blobs: [CAGradientLayer] = []
    private let lightGroup = CALayer()
    private let halo = CAGradientLayer()
    private let core = CAGradientLayer()

    /// 最近一次 apply 的状态，尺寸变化时用它重排
    private var progress: Double = 0
    private var time: TimeInterval = 0
    private var laidOutSize: CGSize = .zero

    init(scene: BackdropScene) {
        self.scene = scene
        super.init(frame: .zero)

        // layer-hosting：先给 layer 再打开 wantsLayer，层树完全由我们管理。
        // 子层用左上原点的屏幕坐标，和 SwiftUI 排版一致。放进窗口后 AppKit 会按 isFlipped
        // 重设根层的 isGeometryFlipped，所以两处都要声明，只设图层的话上屏后会上下颠倒
        let root = CALayer()
        root.isGeometryFlipped = true
        layer = root
        wantsLayer = true

        let theme = scene.theme
        let baseLocations = FlowMotion.baseLocations.map { NSNumber(value: $0) }
        for (gradient, colors) in [(baseStart, theme.baseStart), (baseEnd, theme.baseEnd)] {
            gradient.type = .axial
            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)
            gradient.locations = baseLocations
            gradient.colors = colors.map { CGColor.rgb($0) }
            root.addSublayer(gradient)
        }

        let falloffLocations = FlowMotion.falloffLocations.map { NSNumber(value: $0) }
        for blob in theme.blobs {
            let gradient = Self.radialLayer()
            gradient.locations = falloffLocations
            gradient.colors = FlowMotion.falloffAlphas.map { CGColor.rgb(blob.rgb, alpha: blob.alpha * $0) }
            blobGroup.addSublayer(gradient)
            blobs.append(gradient)
        }
        // 组透明度逐层乘到子层上，和对比度验收的计算模型一致。
        // macOS 默认会先把子层合成再整体乘透明度，光源中段会暗 17%–30%
        blobGroup.allowsGroupOpacity = false
        lightGroup.allowsGroupOpacity = false
        root.addSublayer(blobGroup)

        let lightLocations = FlowMotion.lightLocations.map { NSNumber(value: $0) }
        for (gradient, stops) in [(halo, theme.halo), (core, theme.core)] {
            Self.configureRadial(gradient)
            gradient.locations = lightLocations
            gradient.colors = stops.map { CGColor.rgb($0.rgb, alpha: $0.alpha) }
            lightGroup.addSublayer(gradient)
        }
        root.addSublayer(lightGroup)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        apply(progress: progress, time: time)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        // 手动创建的层默认按 1x 绘制，跟随屏幕的 Retina 倍率
        let scale = window?.backingScaleFactor ?? 2
        let all: [CALayer] = [baseStart, baseEnd, blobGroup, lightGroup, halo, core] + blobs
        for layer in all { layer.contentsScale = scale }
    }

    /// 按休息进度（0...1）和流动时间（秒）摆放各层。一次事务写完，WindowServer 只合成一帧
    func apply(progress p: Double, time t: TimeInterval) {
        progress = p
        time = t
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let stage = Stage(size: size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 尺寸只在屏幕大小变化时重设：改 bounds 会让渐变重新绘制，每步只动位置和透明度
        if size != laidOutSize {
            laidOutSize = size
            for layer in [baseStart, baseEnd, blobGroup, lightGroup] as [CALayer] {
                layer.frame = bounds
            }
            for (layer, slot) in zip(blobs, FlowMotion.slots) {
                let r = slot.radius * size.height
                layer.bounds = CGRect(x: 0, y: 0, width: 2 * r, height: 2 * r)
            }
            for (layer, radius) in [(halo, FlowMotion.haloRadius), (core, FlowMotion.coreRadius)] {
                let r = radius * stage.scale
                layer.bounds = CGRect(x: 0, y: 0, width: 2 * r, height: 2 * r)
            }
        }

        baseEnd.opacity = Float(p)

        blobGroup.opacity = Float(1 - scene.theme.blobFade * p)
        let drift = 1920 * stage.scale
        for (i, layer) in blobs.enumerated() {
            let slot = FlowMotion.slots[i]
            let phase = scene.phases[i]
            let x = slot.x * size.width + slot.driftX * drift * sin(2 * .pi * t / slot.period + phase.x)
            let y = slot.y * size.height
                + slot.driftY * drift * sin(2 * .pi * t / (FlowMotion.yPeriodRatio * slot.period) + phase.y)
            layer.position = CGPoint(x: x, y: y)
        }

        // 光源起点取「舞台 y=1300」和「屏幕底边以下一个光芯半径」中更低的那个，
        // 16:10、4:3 屏上休息刚开始时光芯也不会露出来
        let startY = max(stage.point(0, FlowMotion.lightStartY).y, size.height + FlowMotion.coreRadius * stage.scale)
        let endY = stage.point(0, FlowMotion.lightEndY).y
        let center = CGPoint(x: stage.point(FlowMotion.lightX, 0).x, y: startY + (endY - startY) * p)
        halo.position = center
        core.position = center
        lightGroup.opacity = Float(FlowMotion.lightOpacityStart + (1 - FlowMotion.lightOpacityStart) * p)

        CATransaction.commit()
    }

    private static func radialLayer() -> CAGradientLayer {
        let layer = CAGradientLayer()
        configureRadial(layer)
        return layer
    }

    /// 径向渐变：中心在层中央，半径为层宽的一半（层是正方形，所以是正圆）
    private static func configureRadial(_ layer: CAGradientLayer) {
        layer.type = .radial
        layer.startPoint = CGPoint(x: 0.5, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 1)
    }
}
