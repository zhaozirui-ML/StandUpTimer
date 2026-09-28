import AppKit

enum Phase: Equatable {
    case idle
    case working
    case shortBreak
    case longBreak

    var isBreak: Bool { self == .shortBreak || self == .longBreak }
}

enum TimerEvent {
    case pomodoroCompleted
    case breakTaken
    case breakSkipped
}

/// 基于墙钟时间的番茄钟状态机。tick 只负责重算剩余时间并触发转换，
/// 因此 App Nap / tick 延迟不会导致计时漂移。
@MainActor
final class TimerEngine {
    private let settings: SettingsStore

    private(set) var phase: Phase = .idle
    private(set) var isPaused = false
    /// 当前循环内已完成的番茄数，驱动长休息节奏
    private(set) var completedPomodoros = 0

    private var phaseEndDate: Date?
    private var pausedRemaining: TimeInterval?
    /// 用户在休息时点了"推迟"，记录待恢复的休息类型
    private var postponedBreak: Phase?
    private var tickTimer: Timer?
    private var activityToken: NSObjectProtocol?
    private var sleepDate: Date?

    var onChange: (() -> Void)?
    var onTransition: ((_ from: Phase, _ to: Phase) -> Void)?
    var onEvent: ((TimerEvent) -> Void)?

    /// 调试加速：STANDUP_TIMESCALE=60 时 1 配置分钟 = 1 真实秒
    private let timeScale: Double

    init(settings: SettingsStore) {
        self.settings = settings
        if let raw = ProcessInfo.processInfo.environment["STANDUP_TIMESCALE"],
           let scale = Double(raw), scale > 0 {
            timeScale = scale
        } else {
            timeScale = 1
        }
        observeSleepWake()
    }

    /// 真实剩余秒数
    var remaining: TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        guard let phaseEndDate else { return 0 }
        return max(0, phaseEndDate.timeIntervalSinceNow)
    }

    /// 按配置时间显示的剩余秒数（timescale 下菜单栏仍显示 25:00 起跳）
    var displayRemaining: TimeInterval { remaining * timeScale }

    // MARK: - 控制

    func startWork() {
        postponedBreak = nil
        transition(to: .working)
    }

    func pause() {
        guard phase != .idle, !isPaused else { return }
        pausedRemaining = remaining
        phaseEndDate = nil
        isPaused = true
        stopTicking()
        onChange?()
    }

    func resume() {
        guard isPaused, let r = pausedRemaining else { return }
        phaseEndDate = Date().addingTimeInterval(r)
        pausedRemaining = nil
        isPaused = false
        startTicking()
        onChange?()
    }

    func togglePause() { isPaused ? resume() : pause() }

    func skipPhase() {
        switch phase {
        case .idle:
            break
        case .working:
            // 跳过工作直接休息，不计入番茄数
            let target = postponedBreak ?? nextBreak()
            postponedBreak = nil
            transition(to: target)
        case .shortBreak, .longBreak:
            onEvent?(.breakSkipped)
            transition(to: .working)
        }
    }

    /// 推迟休息 5 分钟：休息中 → 回到 5 分钟的工作片段，结束后恢复完整休息；
    /// 工作中 → 当前阶段延长 5 分钟
    func postpone() {
        switch phase {
        case .idle:
            break
        case .working:
            let extra = scaled(5 * 60)
            if isPaused {
                pausedRemaining = (pausedRemaining ?? 0) + extra
            } else {
                phaseEndDate = phaseEndDate?.addingTimeInterval(extra)
            }
            onChange?()
        case .shortBreak, .longBreak:
            postponedBreak = phase
            transition(to: .working, duration: scaled(5 * 60))
        }
    }

    /// 重置当前阶段倒计时为完整时长（不触发阶段转换副作用）
    func resetPhase() {
        guard phase != .idle else { return }
        isPaused = false
        pausedRemaining = nil
        phaseEndDate = Date().addingTimeInterval(defaultDuration(for: phase))
        startTicking()
        onChange?()
    }

    func stop() {
        postponedBreak = nil
        completedPomodoros = 0
        transition(to: .idle)
    }

    // MARK: - 状态机内部

    private func nextBreak() -> Phase {
        if completedPomodoros > 0, completedPomodoros % settings.longBreakEvery == 0 {
            return .longBreak
        }
        return .shortBreak
    }

    private func phaseCompleted() {
        switch phase {
        case .idle:
            break
        case .working:
            if let postponed = postponedBreak {
                postponedBreak = nil
                transition(to: postponed)
            } else {
                completedPomodoros += 1
                onEvent?(.pomodoroCompleted)
                transition(to: nextBreak())
            }
        case .shortBreak, .longBreak:
            onEvent?(.breakTaken)
            transition(to: .working)
        }
    }

    private func transition(to newPhase: Phase, duration: TimeInterval? = nil) {
        let from = phase
        phase = newPhase
        isPaused = false
        pausedRemaining = nil
        if newPhase == .idle {
            phaseEndDate = nil
            stopTicking()
        } else {
            phaseEndDate = Date().addingTimeInterval(duration ?? defaultDuration(for: newPhase))
            startTicking()
        }
        onTransition?(from, newPhase)
        onChange?()
    }

    private func defaultDuration(for phase: Phase) -> TimeInterval {
        switch phase {
        case .idle: return 0
        case .working: return scaled(TimeInterval(settings.workMinutes) * 60)
        case .shortBreak: return scaled(TimeInterval(settings.shortBreakMinutes) * 60)
        case .longBreak: return scaled(TimeInterval(settings.longBreakMinutes) * 60)
        }
    }

    private func scaled(_ seconds: TimeInterval) -> TimeInterval { seconds / timeScale }

    private func tick() {
        guard !isPaused, phase != .idle else { return }
        if remaining <= 0 {
            phaseCompleted()
        } else {
            onChange?()
        }
    }

    private func startTicking() {
        stopTicking()
        let interval = max(0.05, 1.0 / timeScale)
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { self.tick() }
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
        if activityToken == nil {
            activityToken = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Pomodoro timer running"
            )
        }
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    // MARK: - 睡眠/唤醒

    private func observeSleepWake() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.systemWillSleep() }
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.systemDidWake() }
        }
    }

    private func systemWillSleep() {
        guard phase != .idle, !isPaused else { return }
        sleepDate = Date()
        pause()
    }

    private func systemDidWake() {
        guard let sleepDate else { return }
        self.sleepDate = nil
        let asleep = Date().timeIntervalSince(sleepDate)
        if asleep >= scaled(5 * 60) {
            // 离开超过 5 分钟视为已经休息过，重新开始新的工作番茄
            if phase.isBreak { onEvent?(.breakTaken) }
            postponedBreak = nil
            transition(to: .working)
        } else {
            resume()
        }
    }
}
