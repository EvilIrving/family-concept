import SwiftUI

struct FloatButton: View {
    enum Kind {
        case icon
        case extended(String)
    }

    let systemImage: String
    var kind: Kind = .icon
    var badgeCount: Int? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch kind {
                case .icon:
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColor.textOnBrand)
                        .frame(width: 56, height: 56)
                        .background(AppColor.green800, in: Circle())
                case let .extended(title):
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .bold))
                        Text(title)
                            .font(AppTypography.bodyStrong)
                    }
                    .foregroundStyle(AppColor.textOnBrand)
                    .padding(.horizontal, AppSpacing.lg)
                    .frame(height: 56)
                    .background(AppColor.green800, in: Capsule())
                }
            }
            .overlay(alignment: .topTrailing) {
                if let badgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(AppColor.danger, in: Capsule())
                        .offset(x: 6, y: -6)
                }
            }
            .shadow(color: AppShadow.sheetColor, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}
