import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let engine: TimerEngine
    private let stats: StatsStore
    private let settings: SettingsStore

    var onOpenSettings: (() -> Void)?

    private let menu = NSMenu()
    private let stateItem = NSMenuItem()
    private let todayItem = NSMenuItem()
    private let startItem = NSMenuItem()
    private let pauseItem = NSMenuItem()
    private let skipItem = NSMenuItem()
    private let postponeItem = NSMenuItem()
    private let resetItem = NSMenuItem()
    private let stopItem = NSMenuItem()
    private let breakDurationItem = NSMenuItem()
    private let breakDurationMenu = NSMenu()
    private let breakDurationChoices = [3, 5, 8, 10, 15, 20]

    init(engine: TimerEngine, stats: StatsStore, settings: SettingsStore) {
        self.engine = engine
        self.stats = stats
        self.settings = settings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        buildMenu()
        statusItem.menu = menu
        refresh()
    }

    func refresh() {
        guard let button = statusItem.button else { return }
        // 等宽数字：倒计时每秒变化时宽度不变，不会推动菜单栏里的其他图标
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.imagePosition = .imageLeft
        // 暂停时用系统原生的禁用外观整体变灰
        button.appearsDisabled = engine.isPaused
        switch engine.phase {
        case .idle:
            button.image = MenuBarIcon.full
            button.title = ""
        case .working:
            button.image = MenuBarIcon.full
            button.title = " " + timeString(engine.displayRemaining)
        case .shortBreak, .longBreak:
            // 休息时只剩站着的小人：现在是站立时间
            button.image = MenuBarIcon.standing
            button.title = " " + timeString(engine.displayRemaining)
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        stateItem.isEnabled = false
        todayItem.isEnabled = false

        startItem.target = self
        startItem.action = #selector(startTapped)
        startItem.title = "开始番茄钟"

        pauseItem.target = self
        pauseItem.action = #selector(pauseTapped)

        skipItem.target = self
        skipItem.action = #selector(skipTapped)

        postponeItem.target = self
        postponeItem.action = #selector(postponeTapped)
        postponeItem.title = "推迟休息 5 分钟"

        resetItem.target = self
        resetItem.action = #selector(resetTapped)
        resetItem.title = "重置当前倒计时"

        stopItem.target = self
        stopItem.action = #selector(stopTapped)
        stopItem.title = "停止计时"

        breakDurationItem.title = "站立休息时长"
        breakDurationItem.submenu = breakDurationMenu

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(settingsTapped), keyEquivalent: ",")
        settingsItem.target = self

        let quitItem = NSMenuItem(title: "退出 StandUpTimer", action: #selector(quitTapped), keyEquivalent: "q")
        quitItem.target = self

        menu.addItem(stateItem)
        menu.addItem(todayItem)
        menu.addItem(.separator())
        menu.addItem(startItem)
        menu.addItem(pauseItem)
        menu.addItem(skipItem)
        menu.addItem(postponeItem)
        menu.addItem(resetItem)
        menu.addItem(stopItem)
        menu.addItem(.separator())
        menu.addItem(breakDurationItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        let today = stats.today
        todayItem.title = "今日：\(today.pomodorosCompleted) 番茄 · \(today.breaksTaken) 次站立"
        rebuildBreakDurationMenu()

        switch engine.phase {
        case .idle:
            stateItem.title = "未开始"
            startItem.isHidden = false
            pauseItem.isHidden = true
            skipItem.isHidden = true
            postponeItem.isHidden = true
            resetItem.isHidden = true
            stopItem.isHidden = true
        case .working:
            stateItem.title = engine.isPaused
                ? "已暂停 · 工作中"
                : "工作中 · 已完成 \(engine.completedPomodoros) 个番茄"
            startItem.isHidden = true
            pauseItem.isHidden = false
            pauseItem.title = engine.isPaused ? "继续" : "暂停"
            skipItem.isHidden = false
            skipItem.title = "跳过：立即休息"
            postponeItem.isHidden = false
            resetItem.isHidden = false
            stopItem.isHidden = false
        case .shortBreak, .longBreak:
            stateItem.title = engine.phase == .longBreak ? "长休息中" : "站立休息中"
            startItem.isHidden = true
            pauseItem.isHidden = false
            pauseItem.title = engine.isPaused ? "继续" : "暂停"
            skipItem.isHidden = false
            skipItem.title = "跳过休息"
            postponeItem.isHidden = false
            resetItem.isHidden = false
            stopItem.isHidden = false
        }
    }

    /// 快捷调整站立休息时长，勾选当前值（改动下一次休息生效）
    private func rebuildBreakDurationMenu() {
        breakDurationMenu.removeAllItems()
        let current = settings.shortBreakMinutes
        var choices = breakDurationChoices
        if !choices.contains(current) {
            choices.append(current)
            choices.sort()
        }
        for minutes in choices {
            let item = NSMenuItem(title: "\(minutes) 分钟", action: #selector(breakDurationSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            item.state = minutes == current ? .on : .off
            breakDurationMenu.addItem(item)
        }
    }

    @objc private func startTapped() { engine.startWork() }
    @objc private func pauseTapped() { engine.togglePause() }
    @objc private func skipTapped() { engine.skipPhase() }
    @objc private func postponeTapped() { engine.postpone() }
    @objc private func resetTapped() { engine.resetPhase() }
    @objc private func breakDurationSelected(_ sender: NSMenuItem) { settings.shortBreakMinutes = sender.tag }
    @objc private func stopTapped() { engine.stop() }
    @objc private func settingsTapped() { onOpenSettings?() }
    @objc private func quitTapped() { NSApp.terminate(nil) }
}
