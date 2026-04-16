import SwiftUI

extension View {
    func appPageBackground() -> some View {
        background(AppSemanticColor.background.ignoresSafeArea())
    }

    func appShadow(_ token: AppShadow.Token) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}
