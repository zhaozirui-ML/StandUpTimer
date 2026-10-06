import AppKit
import SwiftUI

/// 无边框窗口默认拒绝成为 key window，按钮将不可点击，因此需要子类放开。
/// 用 NSPanel + .nonactivatingPanel：App 不激活也能接收键盘，否则 Esc 会落到下层 App，需要先点一下遮罩才生效。
/// Esc 在窗口层捕获（比 SwiftUI onExitCommand 更可靠），按下和松开分开上报，用来实现长按。
final class OverlayWindow: NSPanel {
    var onEscapeDown: (() -> Void)?
    var onEscapeUp: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            // 按住时系统会不断发送重复的 keyDown，只认第一次
            if !event.isARepeat { onEscapeDown?() }
        } else {
            super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscapeUp?()
        } else {
            super.keyUp(with: event)
        }
    }
}

@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []
    /// 正在淡出的窗口：已经不算「可见」，淡出结束后 orderOut
    private var fadingWindows: [OverlayWindow] = []
    private let model = OverlayModel()
    private let clock = BackdropClock()
    private var scene: BackdropScene?
    private let skip: () -> Void
    private let postpone: () -> Void
    private var screenObserver: NSObjectProtocol?
    // 长按 Esc 跳过：按住满 holdDuration 秒才生效，避免误触
    private let holdDuration: TimeInterval = 1
    private var holdStart: Date?
    private var holdTimer: Timer?

    var isVisible: Bool { !windows.isEmpty }

    init(skip: @escaping () -> Void, postpone: @escaping () -> Void) {
        self.skip = skip
        self.postpone = postpone
    }

    func show(isLongBreak: Bool, total: TimeInterval) {
        // 上一次的淡出还没结束就直接收掉，立即重建
        finishFadeOut()

        let theme = BreakTheme.named(.sunrise)
            .adjusted(increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
        // 主题和流动相位在休息开始时定一次，整段休息不变；多块屏幕共用
        scene = BackdropScene.random(theme: theme)
        model.theme = theme
        model.isLongBreak = isLongBreak
        model.total = total
        model.skipProgress = 0

        clock.start()
        buildWindows(fadeIn: true)
        observeScreenChanges()
    }

    func update(remaining: TimeInterval) {
        model.remaining = remaining
        clock.setProgress(model.progress)
    }

    /// 0.35 秒淡出后收起，和进场的 0.5 秒淡入对称
    func hide() {
        // 只停计时器、保留长按进度：长按跳过成功后，淡出画面停在「已填满」的状态
        stopHoldTimer()
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
        clock.stop()

        let closing = windows
        windows = []
        guard !closing.isEmpty else { return }
        for window in closing {
            // 淡出期间 Esc 不再触发跳过。点击照常由窗口接住，不会穿透到下层 App；
            // 重复点「推迟」由 AppDelegate 里的 isBreak 检查挡住
            window.onEscapeDown = nil
            window.onEscapeUp = nil
        }
        fadingWindows += closing
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for window in closing { window.animator().alphaValue = 0 }
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.finishFadeOut() }
        })
    }

    private func finishFadeOut() {
        for window in fadingWindows { window.orderOut(nil) }
        fadingWindows = []
    }

    private func buildWindows(fadeIn: Bool) {
        guard let scene else { return }
        for window in windows { window.orderOut(nil) }
        windows = []

        for screen in NSScreen.screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                // .nonactivatingPanel 必须在初始化时传入，事后再改 styleMask 不会生效
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            // NSPanel 默认在 App 失去激活时自动隐藏，遮罩不能这样
            window.hidesOnDeactivate = false
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.onEscapeDown = { [weak self] in self?.beginHold() }
            window.onEscapeUp = { [weak self] in self?.cancelHold() }

            // 背景在下（CALayer 层树，由 BackdropClock 步进），SwiftUI 排版在上（透明背景）
            let size = screen.frame.size
            let container = NSView(frame: CGRect(origin: .zero, size: size))
            let backdrop = FlowBackdropView(scene: scene)
            let host = NSHostingView(rootView: OverlayView(model: model, postpone: postpone))
            for view in [backdrop, host] as [NSView] {
                view.frame = container.bounds
                view.autoresizingMask = [.width, .height]
                container.addSubview(view)
            }
            window.contentView = container
            window.setFrame(screen.frame, display: true)
            clock.register(backdrop)

            // 淡入用窗口透明度，背景和文字一起进场。屏幕插拔重建时不再淡入
            window.alphaValue = fadeIn ? 0 : 1
            // 不激活 App，避免打乱下层窗口/全屏 Space
            window.orderFrontRegardless()
            windows.append(window)
        }

        if fadeIn {
            let fading = windows
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                for window in fading { window.animator().alphaValue = 1 }
            }
        }

        // 只让鼠标所在屏幕的窗口成为 key，吞掉键盘输入（长按 Esc = 跳过休息）
        let mouse = NSEvent.mouseLocation
        let keyWindow = windows.first { $0.screen?.frame.contains(mouse) == true } ?? windows.first
        keyWindow?.makeKey()
    }

    private func beginHold() {
        guard holdTimer == nil else { return }
        holdStart = Date()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.advanceHold()
            }
        }
    }

    private func advanceHold() {
        guard let holdStart else { return }
        let p = min(1, Date().timeIntervalSince(holdStart) / holdDuration)
        model.skipProgress = p
        if p >= 1 {
            stopHoldTimer()
            skip()
        }
    }

    /// 松开 Esc：停计时器并清空进度
    private func cancelHold() {
        stopHoldTimer()
        model.skipProgress = 0
    }

    private func stopHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdStart = nil
    }

    private func observeScreenChanges() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible else { return }
                self.buildWindows(fadeIn: false)
            }
        }
    }
}
