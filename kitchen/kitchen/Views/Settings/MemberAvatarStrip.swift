import SwiftUI

/// 成员头像横向滚动条组件
struct MemberAvatarStrip: View {
    let members: [Member]
    let currentAccountID: String?
    let onMemberTap: (Member) -> Void

    private let colors: [Color] = [
        AppSemanticColor.interactiveSecondaryPressed,
        AppSemanticColor.surfaceSecondary,
        AppSemanticColor.interactiveSecondary,
        AppSemanticColor.toastAccent,
        AppSemanticColor.surfaceTertiary,
        AppSemanticColor.successBackground
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -14) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                        memberAvatarButton(member, colorIndex: index)
                            .zIndex(Double(index))
                    }
                }
                .padding(.leading, AppSpacing.sm)
                .padding (.vertical, AppSpacing.xxs)
                .padding (.trailing, AppSpacing.xs)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                members.count > 6
                    ? "厨房成员，共 \(members.count) 人，横向滑动可查看全部"
                    : "厨房成员，共 \(members.count) 人"
            )

            if members.count > 6 {
                Text("共 \(members.count) 人，左滑可查看其余成员")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppSemanticColor.textTertiary)
            }
        }
    }

    private func memberAvatarButton(_ member: Member, colorIndex: Int) -> some View {
        let isCurrentAccount = member.accountId == currentAccountID
        let initials = String(member.nickName.prefix(1))

        return Button {
            HapticManager.shared.fire(.selection)
            onMemberTap(member)
        } label: {
            ZStack {
                Circle()
                    .fill(colors[colorIndex % colors.count])
                    .overlay(
                        Circle()
                            .stroke(AppSemanticColor.surface, lineWidth: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(isCurrentAccount ? AppSemanticColor.brandAccent : AppSemanticColor.border, lineWidth: isCurrentAccount ? 2 : 1)
                    )

                Text(initials)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(isCurrentAccount ? AppSemanticColor.primary : AppSemanticColor.textPrimary)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .shadow(color: AppSemanticColor.shadowSubtle, radius: 1, y: 1)
        }
        .buttonStyle(MemberAvatarButtonStyle())
        .accessibilityLabel("\(member.nickName)，\(member.role.title)")
    }
}

private struct MemberAvatarButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : AppMotion.press, value: configuration.isPressed)
    }
}
