import SwiftUI

@MainActor
final class OverlayModel: ObservableObject {
    @Published var remaining: TimeInterval = 0
    @Published var isLongBreak = false
}

struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    let skip: () -> Void
    let postpone: () -> Void

    private var timeString: String {
        let total = Int(model.remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()

            VStack(spacing: 28) {
                Text(model.isLongBreak ? "长休息，好好放松" : "站起来活动一下")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)

                Text(timeString)
                    .font(.system(size: 120, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text("离开屏幕，伸展身体，看看远处 🧘")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.7))

                Button(action: postpone) {
                    Text("推迟 5 分钟")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .controlSize(.large)
                .padding(.top, 24)

                Text("点击任意位置或按 Esc 跳过休息")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: skip)
    }
}
