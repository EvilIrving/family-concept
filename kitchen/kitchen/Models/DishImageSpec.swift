import Foundation
import CoreGraphics
import CoreImage

enum DishImageSpec {
    static let viewportAspectRatio: CGFloat = 4.0 / 3.0
    static let mimeType = "image/png"
    static let fileExtension = "png"
    static let viewportCornerRadius: CGFloat = 26
    static let shutterOuterDiameter: CGFloat = 84
    static let shutterInnerDiameter: CGFloat = 62
    static let canvasPixelSize: CGSize = CGSize(width: 1280, height: 960)
    static let subjectFillRatio: CGFloat = 0.85
    static let strokeWidthPixels: CGFloat = 24
    static let strokeColor: CIColor = .black
    static var r2PublicBaseURL: String {
        Bundle.main.infoDictionary?["R2PublicBaseURL"] as? String ?? ""
    }
}
