import AppKit
import SwiftUI

/// 无边框窗口默认拒绝成为 key window，按钮将不可点击，因此需要子类放开。
/// Esc 在窗口层捕获（比 SwiftUI onExitCommand 更可靠，且保证只触发一次）。
final class OverlayWindow: NSWindow {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onEscape?()
        } else {
            super.keyDown(with: event)
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

    var isVisible: Bool { !windows.isEmpty }

    init(skip: @escaping () -> Void, postpone: @escaping () -> Void) {
        self.skip = skip
        self.postpone = postpone
    }

    func show(isLongBreak: Bool) {
        model.isLongBreak = isLongBreak
        buildWindows()
        observeScreenChanges()
    }

    func update(remaining: TimeInterval) {
        model.remaining = remaining
    }

    func hide() {
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
            window.onEscape = skip
            window.contentView = NSHostingView(
                rootView: OverlayView(model: model, skip: skip, postpone: postpone)
            )
            window.setFrame(screen.frame, display: true)
            // 不激活 App，避免打乱下层窗口/全屏 Space
            window.orderFrontRegardless()
            windows.append(window)
        }

        // 只让鼠标所在屏幕的窗口成为 key，吞掉键盘输入（Esc = 推迟）
        let mouse = NSEvent.mouseLocation
        let keyWindow = windows.first { $0.screen?.frame.contains(mouse) == true } ?? windows.first
        keyWindow?.makeKey()
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
