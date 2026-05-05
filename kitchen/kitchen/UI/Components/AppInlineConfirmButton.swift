import SwiftUI

struct AppInlineConfirmButton: View {
    let title: String
    let confirmTitle: String
    var role: AppButton.Role = .destructive
    var size: AppButton.Size = .md
    var fullWidth: Bool = true
    var resetAfter: Duration = .seconds(3)
    let action: () async -> Void

    @State private var isPendingConfirm = false
    @State private var resetToken = 0
    @State private var phase: LoadingPhase<Void> = .idle

    var body: some View {
        AppButton(
            title: phase.isLoading ? confirmTitle : (isPendingConfirm ? confirmTitle : title),
            role: role,
            size: size,
            fullWidth: fullWidth,
            phase: phase
        ) {
            if isPendingConfirm {
                isPendingConfirm = false
                resetToken &+= 1
                phase = .loading()
                Task { @MainActor in
                    await action()
                    phase = .idle
                }
            } else {
                isPendingConfirm = true
                resetToken &+= 1
                let token = resetToken
                Task { @MainActor in
                    try? await Task.sleep(for: resetAfter)
                    if token == resetToken {
                        isPendingConfirm = false
                    }
                }
            }
        }
    }
}
