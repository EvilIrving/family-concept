import SwiftUI

struct MenuEmptyStateView: View {
    let feedback: AppFeedback
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer(minLength: 0)

            Text(feedback.title ?? L10n.tr("Nothing here yet"))
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppSemanticColor.textPrimary)
                .multilineTextAlignment(.center)

            if let hint = feedback.message {
                Text(hint)
                    .font(AppTypography.body)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
