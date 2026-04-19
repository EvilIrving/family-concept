import Foundation
import CoreGraphics

enum DishImageSpec {
    static let viewportAspectRatio: CGFloat = 1.0
    static let outputSize = CGSize(width: 1200, height: 1200)
    static let subjectFillRatio: CGFloat = 0.8
    static let mimeType = "image/png"
    static let fileExtension = "png"
    static let viewportHorizontalInset: CGFloat = 16
    static let viewportCornerRadius: CGFloat = 26
    static let shutterOuterDiameter: CGFloat = 84
    static let shutterInnerDiameter: CGFloat = 62
    static var r2PublicBaseURL: String {
        Bundle.main.infoDictionary?["R2PublicBaseURL"] as? String ?? ""
    }
}
