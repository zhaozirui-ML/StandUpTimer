import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: SettingsStore!
    private var stats: StatsStore!
    private var sound: SoundPlayer!
    private var engine: TimerEngine!
    private var overlay: OverlayController!
    private var statusController: StatusItemController!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        settings = SettingsStore()
        stats = StatsStore()
        sound = SoundPlayer(settings: settings)
        engine = TimerEngine(settings: settings)
        // 只在休息阶段响应，避免重复触发时连跳两个阶段
        overlay = OverlayController(
            skip: { [weak self] in
                guard let self, self.engine.phase.isBreak else { return }
                self.engine.skipPhase()
            },
            postpone: { [weak self] in
                guard let self, self.engine.phase.isBreak else { return }
                self.engine.postpone()
            }
        )
        statusController = StatusItemController(engine: engine, stats: stats)
        statusController.onOpenSettings = { [weak self] in self?.openSettings() }

        engine.onChange = { [weak self] in self?.refresh() }
        engine.onTransition = { [weak self] from, to in self?.handleTransition(from: from, to: to) }
        engine.onEvent = { [weak self] event in self?.stats.record(event) }

        LoginItemManager.reassertIfNeeded(settings: settings)

        // 工具的使命就是提醒，启动即开始计时
        engine.startWork()
    }

    private func handleTransition(from: Phase, to: Phase) {
        if to.isBreak {
            sound.play()
            // 主题只在休息开始时决定一次：自动模式按此刻的时段和系统外观选
            let theme = settings.breakTheme.resolve(at: Date(), isDark: BreakThemeChoice.systemIsDark)
            overlay.show(isLongBreak: to == .longBreak, total: engine.displayRemaining, theme: theme)
            overlay.update(remaining: engine.displayRemaining)
        } else if from.isBreak {
            if to == .working { sound.play() }
            overlay.hide()
        }
        refresh()
    }

    private func refresh() {
        statusController.refresh()
        if overlay.isVisible {
            overlay.update(remaining: engine.displayRemaining)
        }
    }

    private func openSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: host)
            window.title = "StandUpTimer 设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
