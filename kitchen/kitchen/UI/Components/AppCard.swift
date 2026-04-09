import SwiftUI

struct AppCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.md
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            content
        }
        .padding(padding)
        .background(AppColor.surfacePrimary, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppColor.lineSoft, lineWidth: 1)
        }
        .shadow(color: AppShadow.cardColor, radius: 18, x: 0, y: 6)
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
                    .foregroundStyle(AppColor.green700)
            }
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColor.textPrimary)
            if let detail {
                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }
}

struct AppPill: View {
    let title: String
    var tint: Color = AppColor.green800
    var background: Color = AppColor.green100

    var body: some View {
        Text(title)
            .font(AppTypography.micro)
            .foregroundStyle(tint)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(background, in: Capsule())
    }
}
