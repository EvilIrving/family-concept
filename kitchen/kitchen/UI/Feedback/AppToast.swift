import SwiftUI

struct AppToastData: Identifiable {
    let id = UUID()
    var message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
}

struct AppToastHost: ViewModifier {
    @Binding var toast: AppToastData?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppSemanticColor.toastAccent)

                        Text(toast.message)
                            .font(AppTypography.body)
                            .foregroundStyle(AppSemanticColor.onPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let actionTitle = toast.actionTitle, let action = toast.action {
                            Button(actionTitle) {
                                action()
                                dismiss()
                            }
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppSemanticColor.toastAccent)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppSemanticColor.toastBackground, in: Capsule())
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(2.2))
                        dismiss()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: toast?.id)
    }

    private func dismiss() {
        withAnimation {
            toast = nil
        }
    }
}

extension View {
    func appToast(_ toast: Binding<AppToastData?>) -> some View {
        modifier(AppToastHost(toast: toast))
    }
}
