import SwiftUI

struct AppCardList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(AppSpacing.md)
            .background(
                AppComponentColor.Card.background,
                in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(AppComponentColor.Card.border, lineWidth: 1)
            }
    }
}
