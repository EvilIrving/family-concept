import SwiftUI

struct AppShakeEffect: GeometryEffect {
    var travel: CGFloat = 8
    var oscillations: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = travel * sin(animatableData * .pi * oscillations)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

struct AppValidationFeedbackModifier: ViewModifier {
    var isInvalid: Bool
    var trigger: Int

    func body(content: Content) -> some View {
        content
            .modifier(AppShakeEffect(animatableData: isInvalid ? CGFloat(trigger) : 0))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .inset(by: 0.5)
                    .stroke(isInvalid ? AppSemanticColor.danger : AppSemanticColor.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .animation(.easeInOut(duration: 0.34), value: trigger)
            .animation(.easeInOut(duration: 0.16), value: isInvalid)
    }
}

extension View {
    func appValidationFeedback(isInvalid: Bool, trigger: Int) -> some View {
        modifier(AppValidationFeedbackModifier(isInvalid: isInvalid, trigger: trigger))
    }
}
