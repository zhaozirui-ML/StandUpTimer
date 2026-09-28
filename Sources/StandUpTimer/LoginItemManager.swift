import Foundation
import ServiceManagement

@MainActor
enum LoginItemManager {
    /// 裸 `swift run`（无 bundle）下不可用
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// 重新构建 bundle 后注册可能失效；启动时按用户偏好幂等地重新注册
    static func reassertIfNeeded(settings: SettingsStore) {
        guard isAvailable, settings.launchAtLogin else { return }
        try? SMAppService.mainApp.register()
    }
}
