import SwiftUI

struct MenuCartBar: View {
    let cartCount: Int
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppSemanticColor.border)
                .frame(height: 1)

            AppButton(title: "已选 \(cartCount) 道菜", leadingIcon: "cart.fill", role: .primary, fullWidth: true) {
                onTap()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
        }
    }
}
