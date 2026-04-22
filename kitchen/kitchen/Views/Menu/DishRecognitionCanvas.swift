import SwiftUI
import UIKit

struct DishRecognitionCanvas: View {
    let displayImage: UIImage
    let scale: CGFloat
    let offset: CGSize
    let viewportSize: CGSize
    let viewportCenter: CGPoint
    let containerSize: CGSize

    var body: some View {
        let baseFrame = dishRecognitionAspectFillFrame(for: displayImage.size, viewportSize: viewportSize)
        let baseOffset = CGSize(
            width: viewportCenter.x - containerSize.width / 2,
            height: viewportCenter.y - containerSize.height / 2
        )

        Color.clear
            .frame(width: containerSize.width, height: containerSize.height)
            .overlay {
                Image(uiImage: displayImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: baseFrame.width * scale, height: baseFrame.height * scale)
                    .offset(x: baseOffset.width + offset.width, y: baseOffset.height + offset.height)
            }
            .clipped()
            .contentShape(Rectangle())
    }
}

struct DishRecognitionPreviewCanvas: View {
    let previewImage: UIImage
    let viewportSize: CGSize

    var body: some View {
        Color.clear
            .frame(width: viewportSize.width, height: viewportSize.height)
            .overlay {
                Image(uiImage: previewImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: viewportSize.width, height: viewportSize.height)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DishImageSpec.viewportCornerRadius,
                    style: .continuous
                )
            )
    }
}

func dishRecognitionAspectFillFrame(for imageSize: CGSize, viewportSize: CGSize) -> CGSize {
    guard imageSize.width > 0, imageSize.height > 0 else {
        return viewportSize
    }

    let fillScale = max(viewportSize.width / imageSize.width, viewportSize.height / imageSize.height)
    return CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
}
