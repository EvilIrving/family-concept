import SwiftUI

/// Toast 数据模型
struct AppToastData: Identifiable {
    enum Placement {
        case top
        case center
    }

    let id = UUID()
    var text: String
    var duration: Duration = .seconds(2.2)
    var placement: Placement = .top
    var showsIcon: Bool = false
    var iconSystemName: String? = nil
    var feedbackLevel: AppFeedbackLevel = .low
    var foregroundColor: Color = AppSemanticColor.onPrimary
    var backgroundColor: Color = Color.black.opacity(0.82)
}

/// Banner 数据模型
struct TopBannerData: Identifiable {
    let id = UUID()
    var text: String
    var autoDismissDuration: Duration? = .seconds(2.2)
    var showsIcon: Bool = false
    var iconSystemName: String? = nil
    var foregroundColor: Color = AppSemanticColor.onPrimary
    var backgroundColor: Color = AppSemanticColor.infoForeground
}

// MARK: - Toast View

struct AppToastView: View {
    let toast: AppToastData

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if toast.showsIcon {
                Image(systemName: toast.iconSystemName ?? "info.circle.fill")
                    .foregroundStyle(toast.foregroundColor)
            }

            Text(toast.text)
                .font(AppTypography.body)
                .foregroundStyle(toast.foregroundColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(toast.backgroundColor, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .shadow(color: AppSemanticColor.shadowSubtle, radius: 16, y: 8)
    }
}

// MARK: - Banner View

struct AppBannerView: View {
    let banner: TopBannerData

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if banner.showsIcon {
                Image(systemName: banner.iconSystemName ?? "info.circle.fill")
                    .foregroundStyle(banner.foregroundColor)
            }

            Text(banner.text)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(banner.foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(banner.backgroundColor, in: Capsule())
        .shadow(color: AppSemanticColor.shadowSubtle, radius: 16, y: 8)
    }
}

// MARK: - View Extension

extension View {
    func appToastHost() -> some View {
        modifier(AppToastHost())
    }
}
