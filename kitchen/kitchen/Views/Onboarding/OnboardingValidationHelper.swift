import Foundation
import SwiftUI

/// Onboarding 表单校验辅助工具
struct OnboardingValidationHelper {
    /// 校验用户名，返回是否有效
    static func validateUserName(_ name: String, shake: inout Int, invalid: inout Bool) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            withAnimation(.easeInOut(duration: 0.34)) { invalid = true }
            shake += 1
            return false
        }
        return true
    }

    /// 校验密码，返回是否有效
    static func validatePassword(_ password: String, shake: inout Int, invalid: inout Bool) -> Bool {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            withAnimation(.easeInOut(duration: 0.34)) { invalid = true }
            shake += 1
            return false
        }
        return true
    }

    /// 校验昵称，返回是否有效
    static func validateNickName(_ nickName: String, shake: inout Int, invalid: inout Bool) -> Bool {
        let trimmed = nickName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            withAnimation(.easeInOut(duration: 0.34)) { invalid = true }
            shake += 1
            return false
        }
        return true
    }

    /// 校验厨房输入，返回是否有效
    static func validateKitchenInput(_ input: String, shake: inout Int, invalid: inout Bool) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            withAnimation(.easeInOut(duration: 0.34)) { invalid = true }
            shake += 1
            return false
        }
        return true
    }

    /// 重置校验状态
    static func resetValidation(_ invalid: inout Bool) {
        withAnimation(.easeInOut(duration: 0.16)) { invalid = false }
    }
}

// Helper to allow withAnimation in non-View context
private func withAnimation(_ animation: SwiftUI.Animation, _ body: () -> Void) {
    SwiftUI.withAnimation(animation, body)
}
