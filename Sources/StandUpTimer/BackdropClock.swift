import AppKit
import CoreGraphics
import IOKit.ps

/// 驱动流动背景：按能耗档位步进色块位置，并把每秒一次的休息进度平滑成连续的光源上升。
///
/// 动画不交给 Core Animation 自己跑（那样 WindowServer 会按屏幕刷新率 60/120Hz 合成），
/// 而是主线程低频步进：每一步在一个事务里写完所有层，WindowServer 每次只合成一帧，帧率由我们锁定。
/// 色块漂移很慢，10Hz 下每步的颜色变化不到 1 个色阶，看起来和连续动画没有区别。
@MainActor
final class BackdropClock {
    enum Level: Equatable {
        /// 正常流动，每秒步进 hz 次
        case flowing(hz: Double)
        /// 定格：色块停在当前位置，光源每秒随进度跳一次
        case still
        /// 遮罩看不见（屏保、锁屏、熄屏），完全不提交
        case paused
    }

    private struct Entry {
        weak var view: FlowBackdropView?
    }

    private var views: [Entry] = []
    private var stepTimer: Timer?
    private var policyTimer: Timer?
    private var occlusionObserver: NSObjectProtocol?
    private(set) var level: Level = .paused

    // 进度在「上一次」和「这一次」刷新之间线性过渡（正式计时滞后 1 秒，肉眼看不出），
    // 剩余时间仍由 TimerEngine 的 phaseEndDate 推算，这里只做显示上的平滑
    private var fromProgress: Double = 0
    private var toProgress: Double = 0
    private var progressStamp: CFTimeInterval = 0
    /// 两次刷新的实际间隔：正式计时约 1 秒，make dev-fast 下只有 0.05 秒
    private var progressInterval: CFTimeInterval = 1
    private var hasProgress = false

    /// 流动时间只在 flowing 档累积：定格或暂停后恢复时接着走，不会跳帧
    private var flowTime: TimeInterval = 0
    private var lastStep: CFTimeInterval = 0

    /// 登记一块屏幕的背景并立即画出当前状态。屏幕插拔重建窗口时，旧视图释放后自动失效
    func register(_ view: FlowBackdropView) {
        views.append(Entry(view: view))
        view.apply(progress: displayedProgress(at: CACurrentMediaTime()), time: flowTime)
        evaluateLevel()
    }

    /// 休息开始：从进度 0 重新开始，之后每秒评估一次能耗档位。先 start 再 register
    func start() {
        stop()
        flowTime = 0
        // 上一次休息留下的进度必须清掉，否则进场首帧会画成上一次的终点（光源已经升起）
        fromProgress = 0
        toProgress = 0
        progressInterval = 1
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluateLevel() }
        }
        timer.tolerance = 0.2
        // .common：打开菜单栏下拉菜单时（事件跟踪模式）背景也不会停住
        RunLoop.main.add(timer, forMode: .common)
        policyTimer = timer
        // 窗口一上屏（或被屏保、锁屏遮住）就立即重新评估，不用等下一次每秒轮询
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluateLevel() }
        }
    }

    func stop() {
        stepTimer?.invalidate()
        stepTimer = nil
        policyTimer?.invalidate()
        policyTimer = nil
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
            self.occlusionObserver = nil
        }
        views = []
        level = .paused
        hasProgress = false
    }

    /// 由遮罩每次刷新时调用（正式计时每秒一次）
    func setProgress(_ p: Double) {
        let now = CACurrentMediaTime()
        if hasProgress {
            fromProgress = displayedProgress(at: now)
            progressInterval = min(1, max(0.05, now - progressStamp))
        } else {
            fromProgress = p
            progressInterval = 1
            hasProgress = true
        }
        toProgress = p
        progressStamp = now
        // 定格档没有步进，进度直接写入：光源和倒计时在同一刻跳动
        if level == .still { applyAll(progress: p) }
    }

    private func displayedProgress(at now: CFTimeInterval) -> Double {
        let k = min(1, max(0, (now - progressStamp) / progressInterval))
        return fromProgress + (toProgress - fromProgress) * k
    }

    // MARK: - 能耗档位

    private func evaluateLevel() {
        views.removeAll { $0.view == nil }
        let visible = views.contains { $0.view?.window?.occlusionState.contains(.visible) == true }
        let next: Level
        if !visible {
            next = .paused
        } else if Self.prefersStill() {
            next = .still
        } else {
            // 电池供电时减半：每步像素变化仍在 1 个色阶以内，GPU 开销减半
            next = .flowing(hz: Self.isOnBattery() ? 5 : 10)
        }
        guard next != level else { return }
        level = next

        stepTimer?.invalidate()
        stepTimer = nil
        switch next {
        case .flowing(let hz):
            lastStep = CACurrentMediaTime()
            let timer = Timer(timeInterval: 1 / hz, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.step() }
            }
            timer.tolerance = 0.1 / hz
            RunLoop.main.add(timer, forMode: .common)
            stepTimer = timer
        case .still:
            applyAll(progress: toProgress)
        case .paused:
            break
        }
    }

    private func step() {
        let now = CACurrentMediaTime()
        // 单步最多推进 0.5 秒，避免系统卡顿后色块突然跳一大段
        flowTime += min(0.5, max(0, now - lastStep))
        lastStep = now
        applyAll(progress: displayedProgress(at: now))
    }

    private func applyAll(progress: Double) {
        for entry in views {
            // 多屏时各自判断：被遮住的那块屏幕跳过，不影响其他屏幕
            guard let view = entry.view, view.window?.occlusionState.contains(.visible) == true else { continue }
            view.apply(progress: progress, time: flowTime)
        }
    }

    /// 以下任一情况背景定格：减弱动态效果、低电量模式、机器过热，
    /// 或者 30 秒没有键盘鼠标输入（人已经离开屏幕，这正是休息的目的）
    private static func prefersStill() -> Bool {
        let info = ProcessInfo.processInfo
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            || info.isLowPowerModeEnabled
            || info.thermalState == .serious || info.thermalState == .critical
            || secondsSinceLastInput() > 30
    }

    private static func secondsSinceLastInput() -> TimeInterval {
        // kCGAnyInputEventType = ~0；读取空闲时长不需要辅助功能权限
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    private static func isOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPSBatteryPowerValue
    }
}
