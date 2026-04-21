import SwiftUI

struct DishRecognitionCanvas: View {
    let displayImage: UIImage
    let scale: CGFloat
    let offset: CGSize
    let isEditing: Bool
    let vpWidth: CGFloat
    let vpHeight: CGFloat
    let viewportCenter: CGPoint
    let containerSize: CGSize

    var body: some View {
        let baseFrame = aspectFillFrame(for: displayImage.size, vpWidth: vpWidth, vpHeight: vpHeight)
        let baseOffset = CGSize(
            width: viewportCenter.x - containerSize.width / 2,
            height: viewportCenter.y - containerSize.height / 2
        )

        return Color.clear
            .frame(width: containerSize.width, height: containerSize.height)
            .overlay(
                Image(uiImage: displayImage)
                    .resizable()
                    .frame(width: baseFrame.width * scale, height: baseFrame.height * scale)
                    .offset(x: baseOffset.width + offset.width, y: baseOffset.height + offset.height)
            )
            .clipped()
            .contentShape(Rectangle())
    }

    private func aspectFillFrame(for imageSize: CGSize, vpWidth: CGFloat, vpHeight: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: vpWidth, height: vpHeight)
        }
        let fillScale = max(vpWidth / imageSize.width, vpHeight / imageSize.height)
        return CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
    }
}

struct DishRecognitionViewportOverlay: View {
    let isEditing: Bool
    let vpWidth: CGFloat
    let vpHeight: CGFloat
    let viewportCenter: CGPoint
    let containerSize: CGSize

    var body: some View {
        ZStack {
            if isEditing {
                darkOverlay
            }
            viewportBorder
        }
    }

    private var darkOverlay: some View {
        Rectangle()
            .fill(AppComponentColor.Cropper.overlay)
            .ignoresSafeArea()
            .overlay(
                RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius)
                    .frame(width: vpWidth, height: vpHeight)
                    .offset(
                        x: viewportCenter.x - containerSize.width / 2,
                        y: viewportCenter.y - containerSize.height / 2
                    )
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
            .allowsHitTesting(false)
    }

    private var viewportBorder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius)
                .strokeBorder(AppComponentColor.Cropper.viewportBorder, lineWidth: AppBorderWidth.strong + 0.5)
                .frame(width: vpWidth, height: vpHeight)

            RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius)
                .strokeBorder(AppComponentColor.Cropper.viewportShadow, lineWidth: 18)
                .blur(radius: 12)
                .frame(width: vpWidth, height: vpHeight)
                .clipShape(RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius))
        }
        .allowsHitTesting(false)
        .opacity(isEditing ? 1 : 0)
    }
}

struct DishRecognitionFinalPreview: View {
    let finalImage: UIImage
    let vpWidth: CGFloat
    let vpHeight: CGFloat
    let viewportCenter: CGPoint

    var body: some View {
        Image(uiImage: finalImage)
            .resizable()
            .scaledToFit()
            .padding(16)
            .frame(width: vpWidth, height: vpHeight)
            .position(x: viewportCenter.x, y: viewportCenter.y)
            .transition(.opacity)
    }
}

struct DishRecognitionRecognizingOverlay: View {
    let subimage: UIImage
    let vpWidth: CGFloat
    let vpHeight: CGFloat
    let viewportCenter: CGPoint

    var body: some View {
        DishConfirmDissolveView(
            sourceImage: subimage,
            produceFinal: { await DishImageProcessor.composeFinalImage(from: subimage) },
            onFinish: { finalImage in
                withAnimation(.easeInOut(duration: 0.2)) {
                    // Handled by parent
                }
            }
        )
        .transition(.opacity)
    }
}
