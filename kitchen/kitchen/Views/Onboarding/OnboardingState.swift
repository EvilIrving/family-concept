import Foundation

/// 认证模式枚举
enum AuthMode { case login, register }

/// 私厨模式枚举
enum KitchenMode { case join, create }

/// 表单字段枚举
enum OnboardingField: Hashable {
    case userName, password, nickName, kitchen
}
