import Foundation
import CoreGraphics
import CoreImage

enum DishImageSpec {
    nonisolated static let viewportAspectRatio: CGFloat = 4.0 / 3.0
    nonisolated static let mimeType = "image/png"
    nonisolated static let fileExtension = "png"
    nonisolated static let viewportCornerRadius: CGFloat = 26
    nonisolated static let shutterOuterDiameter: CGFloat = 84
    nonisolated static let shutterInnerDiameter: CGFloat = 62
    nonisolated static let canvasPixelSize: CGSize = CGSize(width: 1280, height: 960)
    nonisolated static let subjectFillRatio: CGFloat = 0.85
    nonisolated static let strokeWidthPixels: CGFloat = 24
    nonisolated static let strokeColor: CIColor = .black
    static var r2PublicBaseURL: String {
        Bundle.main.infoDictionary?["R2PublicBaseURL"] as? String ?? ""
    }
}
