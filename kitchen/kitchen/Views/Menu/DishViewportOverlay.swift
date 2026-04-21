import SwiftUI

struct DishViewportOverlay: View {
    let isEditing: Bool
    let isRecognizing: Bool
    let vpWidth: CGFloat
    let vpHeight: CGFloat

    var body: some View {
        ZStack {
            if isEditing {
                viewportBorder
            }
        }
        .allowsHitTesting(false)
        .opacity(isEditing && !isRecognizing ? 1 : 0)
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
    }
}

struct DishRecognitionDarkOverlay: View {
    let vpWidth: CGFloat
    let vpHeight: CGFloat
    let viewportCenter: CGPoint
    let containerSize: CGSize

    var body: some View {
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
}
