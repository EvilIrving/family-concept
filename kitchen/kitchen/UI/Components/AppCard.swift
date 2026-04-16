import SwiftUI

struct AppCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.md
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            content
        }
        .padding(padding)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppComponentColor.Card.background)
                .shadow(
                    color: AppShadow.card.color,
                    radius: AppShadow.card.radius,
                    x: AppShadow.card.x,
                    y: AppShadow.card.y
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppComponentColor.Card.border, lineWidth: 1)
        }
    }
}

struct AppSectionHeader: View {
    let eyebrow: String?
    let title: String
    let detail: String?

    init(eyebrow: String? = nil, title: String, detail: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let eyebrow {
                Text(eyebrow)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppComponentColor.Card.eyebrow)
            }
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppSemanticColor.textPrimary)
            if let detail {
                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppSemanticColor.textSecondary)
            }
        }
    }
}

struct AppPill: View {
    let title: String
    var tint: Color = AppSemanticColor.primary
    var background: Color = AppComponentColor.Button.secondaryBackground

    var body: some View {
        Text(title)
            .font(AppTypography.micro)
            .foregroundStyle(tint)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(background, in: Capsule())
    }
}
