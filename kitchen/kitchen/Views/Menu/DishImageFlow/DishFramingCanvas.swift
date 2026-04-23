import SwiftUI
import UIKit

struct DishFramingCanvas: View {
    let displayImage: UIImage
    let scale: CGFloat
    let offset: CGSize
    let viewportCenter: CGPoint
    let containerSize: CGSize

    var body: some View {
        let baseFrame = dishFramingAspectFillSize(for: displayImage.size, containerSize: containerSize)
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

func dishFramingAspectFillSize(for imageSize: CGSize, containerSize: CGSize) -> CGSize {
    guard imageSize.width > 0, imageSize.height > 0 else {
        return containerSize
    }

    let fillScale = max(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
    return CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
}
