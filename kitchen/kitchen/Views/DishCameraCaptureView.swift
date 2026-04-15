import SwiftUI
import AVFoundation

struct DishCameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> DishCameraViewController {
        DishCameraViewController(onCapture: onCapture, onCancel: onCancel)
    }

    func updateUIViewController(_ uiViewController: DishCameraViewController, context: Context) {}
}

final class DishCameraViewController: UIViewController {
    private let onCapture: (UIImage) -> Void
    private let onCancel: () -> Void

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var flashMode: AVCaptureDevice.FlashMode = .auto
    private weak var flashButton: UIButton?

    init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession?.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else { return }

        session.addInput(input)
        session.addOutput(output)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)

        captureSession = session
        photoOutput = output
        previewLayer = preview
    }

    private func setupUI() {
        let vpWidth = view.bounds.width
        let vpHeight = vpWidth / DishImageSpec.viewportAspectRatio
        let vpY = (view.bounds.height - vpHeight) / 2
        let safeTop = view.safeAreaInsets.top
        let safeBottom = view.safeAreaInsets.bottom

        // Dim above
        let topDim = UIView(frame: CGRect(x: 0, y: 0, width: vpWidth, height: vpY))
        topDim.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.addSubview(topDim)

        // Dim below
        let bottomY = vpY + vpHeight
        let bottomDim = UIView(frame: CGRect(x: 0, y: bottomY, width: vpWidth, height: view.bounds.height - bottomY))
        bottomDim.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.addSubview(bottomDim)

        // Viewport border
        let border = UIView(frame: CGRect(x: 0, y: vpY, width: vpWidth, height: vpHeight))
        border.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        border.layer.borderWidth = 1
        view.addSubview(border)

        // Close button
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = .white
        close.frame = CGRect(x: 16, y: safeTop + 8, width: 44, height: 44)
        close.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(close)

        // Flash button
        let flash = UIButton(type: .system)
        flash.setImage(UIImage(systemName: "bolt.badge.automatic.fill"), for: .normal)
        flash.tintColor = .white
        flash.frame = CGRect(x: vpWidth - 60, y: safeTop + 8, width: 44, height: 44)
        flash.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)
        view.addSubview(flash)
        flashButton = flash

        // Shutter button
        let shutterY = view.bounds.height - safeBottom - 100
        let shutter = UIButton(type: .custom)
        shutter.frame = CGRect(x: (vpWidth - 72) / 2, y: shutterY, width: 72, height: 72)
        shutter.layer.cornerRadius = 36
        shutter.layer.borderWidth = 4
        shutter.layer.borderColor = UIColor.white.cgColor
        shutter.backgroundColor = .white
        shutter.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        view.addSubview(shutter)
    }

    @objc private func cancelTapped() { onCancel() }

    @objc private func flashTapped() {
        switch flashMode {
        case .auto:
            flashMode = .on
            flashButton?.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
            flashButton?.tintColor = .yellow
        case .on:
            flashMode = .off
            flashButton?.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
            flashButton?.tintColor = .white
        case .off:
            flashMode = .auto
            flashButton?.setImage(UIImage(systemName: "bolt.badge.automatic.fill"), for: .normal)
            flashButton?.tintColor = .white
        @unknown default:
            break
        }
    }

    @objc private func shutterTapped() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
}

extension DishCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        // Crop to viewport aspect ratio from image center
        let ratio = DishImageSpec.viewportAspectRatio
        let imgW = image.size.width
        let imgH = image.size.height
        let cropH = imgW / ratio
        let cropRect: CGRect

        if cropH <= imgH {
            cropRect = CGRect(x: 0, y: (imgH - cropH) / 2, width: imgW, height: cropH)
        } else {
            let cropW = imgH * ratio
            cropRect = CGRect(x: (imgW - cropW) / 2, y: 0, width: cropW, height: imgH)
        }

        let scale = image.scale
        let scaledRect = cropRect.applying(CGAffineTransform(scaleX: scale, y: scale))
        guard let cgCropped = image.cgImage?.cropping(to: scaledRect) else { return }
        let cropped = UIImage(cgImage: cgCropped, scale: scale, orientation: image.imageOrientation)

        DispatchQueue.main.async { [weak self] in
            self?.onCapture(cropped)
        }
    }
}
