import SwiftUI

struct MenuRow: View {
    @Environment(\.openURL) private var openURL

    let title: String
    var showsDivider: Bool = true
    var isEnabled: Bool = true
    var url: URL? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        rowContent
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEnabled else { return }
                if let url {
                    openURL(url)
                } else {
                    onTap?()
                }
            }
    }

    private var rowContent: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(isEnabled ? AppSemanticColor.textPrimary : AppSemanticColor.textTertiary)
            Spacer()
            if url == nil, onTap == nil {
                Text("Coming later")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: AppIconSize.xs, weight: .semibold))
                .foregroundStyle(AppSemanticColor.textTertiary)
        }
        .frame(minHeight: AppDimension.listRowMinHeight)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider()
                    .overlay(AppSemanticColor.border)
            }
        }
    }
}
