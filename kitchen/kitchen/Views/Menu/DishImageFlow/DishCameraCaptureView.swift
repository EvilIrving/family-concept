import SwiftUI
import UIKit

struct DishCameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            let controller = UIViewController()
            controller.view.backgroundColor = UIColor(AppSemanticColor.cameraBackdrop)

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = "当前设备不可用相机"
            label.textColor = UIColor(AppSemanticColor.cropControlForeground)
            label.font = .preferredFont(forTextStyle: .headline)

            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle("关闭", for: .normal)
            button.setTitleColor(UIColor(AppSemanticColor.cropControlForeground), for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .body)
            button.addAction(UIAction { _ in
                context.coordinator.handleCancel()
            }, for: .touchUpInside)

            controller.view.addSubview(label)
            controller.view.addSubview(button)

            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor, constant: -12),
                button.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
                button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16)
            ])

            return controller
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        picker.showsCameraControls = true
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

extension DishCameraCaptureView {
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            handleCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                handleCancel()
                return
            }
            onCapture(image)
        }

        func handleCancel() {
            onCancel()
        }
    }
}

#Preview {
    DishCameraCaptureView(
        onCapture: { _ in },
        onCancel: {}
    )
    .ignoresSafeArea()
}
