import SwiftUI

/// 设置里「休息画面」的一格：缩略图 + 名字。
/// 主题缩略图直接用真实的 FlowBackdropView 静态渲染一帧，和休息时的画面永远一致，也不需要图片资源
struct ThemeTile: View {
    let choice: BreakThemeChoice
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                thumbnail
                    .aspectRatio(16 / 10, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    }
                Text(choice.title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(choice.helpText)
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch choice {
        case .fixed(let id):
            ThemeThumbnail(theme: BreakTheme.named(id))
        case .auto:
            // 4 条竖向色带，依次是上午、下午、傍晚、夜里，随系统外观变化
            HStack(spacing: 0) {
                ForEach(BreakThemeChoice.autoSequence(isDark: colorScheme == .dark), id: \.self) { id in
                    LinearGradient(
                        colors: BreakTheme.named(id).baseEnd.map { Color(hex: $0) },
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
    }
}

/// 把 FlowBackdropView 嵌进 SwiftUI，静态显示休息进行到 70% 时的一帧（光源已经升起），不登记步进时钟
private struct ThemeThumbnail: NSViewRepresentable {
    let theme: BreakTheme

    func makeNSView(context: Context) -> FlowBackdropView {
        let phases = FlowMotion.slots.map { _ in (x: 0.0, y: 0.0) }
        let view = FlowBackdropView(scene: BackdropScene(theme: theme, phases: phases))
        view.apply(progress: 0.7, time: 0)
        return view
    }

    func updateNSView(_ view: FlowBackdropView, context: Context) {}
}
