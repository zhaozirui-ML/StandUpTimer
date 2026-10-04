import AppKit
import SwiftUI

/// 无边框窗口默认拒绝成为 key window，按钮将不可点击，因此需要子类放开。
/// Esc 在窗口层捕获（比 SwiftUI onExitCommand 更可靠），按下和松开分开上报，用来实现长按。
final class OverlayWindow: NSWindow {
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
    private let model = OverlayModel()
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
        model.isLongBreak = isLongBreak
        model.total = total
        model.skipProgress = 0
        buildWindows()
        observeScreenChanges()
    }

    func update(remaining: TimeInterval) {
        model.remaining = remaining
    }

    func hide() {
        cancelHold()
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
        for window in windows {
            window.orderOut(nil)
        }
        windows = []
    }

    private func buildWindows() {
        for window in windows { window.orderOut(nil) }
        windows = []

        for screen in NSScreen.screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.onEscapeDown = { [weak self] in self?.beginHold() }
            window.onEscapeUp = { [weak self] in self?.cancelHold() }
            window.contentView = NSHostingView(
                rootView: OverlayView(model: model, postpone: postpone)
            )
            window.setFrame(screen.frame, display: true)
            // 不激活 App，避免打乱下层窗口/全屏 Space
            window.orderFrontRegardless()
            windows.append(window)
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
            cancelHold()
            skip()
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdStart = nil
        model.skipProgress = 0
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
                self.buildWindows()
            }
        }
    }
}
