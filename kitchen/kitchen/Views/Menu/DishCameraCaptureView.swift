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

    private let cameraContainer = UIView()
    private let viewportFrameView = UIView()
    private let gridOverlayView = DishCameraGridView()
    private let topOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let bottomOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let helperLabel = UILabel()
    private let flashButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let shutterButton = UIButton(type: .custom)
    private let shutterInnerView = UIView()
    private let statusChip = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))

    private var hasBuiltHierarchy = false

    init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
        setupCamera()
        setupUI()
        updateFlashButtonAppearance()
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
        previewLayer?.frame = cameraContainer.bounds
        previewLayer?.cornerRadius = DishImageSpec.viewportCornerRadius
        viewportFrameView.layer.cornerRadius = DishImageSpec.viewportCornerRadius
        gridOverlayView.layer.cornerRadius = DishImageSpec.viewportCornerRadius
        cameraContainer.layer.shadowPath = UIBezierPath(
            roundedRect: cameraContainer.bounds,
            cornerRadius: DishImageSpec.viewportCornerRadius
        ).cgPath
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        try? device.lockForConfiguration()
        device.videoZoomFactor = 1.0
        device.unlockForConfiguration()

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else { return }

        session.addInput(input)
        session.addOutput(output)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.masksToBounds = true

        captureSession = session
        photoOutput = output
        previewLayer = preview
    }

    private func setupUI() {
        guard !hasBuiltHierarchy else { return }
        hasBuiltHierarchy = true

        cameraContainer.translatesAutoresizingMaskIntoConstraints = false
        viewportFrameView.translatesAutoresizingMaskIntoConstraints = false
        gridOverlayView.translatesAutoresizingMaskIntoConstraints = false
        topOverlay.translatesAutoresizingMaskIntoConstraints = false
        bottomOverlay.translatesAutoresizingMaskIntoConstraints = false
        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterInnerView.translatesAutoresizingMaskIntoConstraints = false
        statusChip.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(cameraContainer)
        view.addSubview(topOverlay)
        view.addSubview(bottomOverlay)
        cameraContainer.addSubview(viewportFrameView)
        cameraContainer.addSubview(gridOverlayView)
        cameraContainer.addSubview(helperLabel)
        topOverlay.contentView.addSubview(closeButton)
        topOverlay.contentView.addSubview(statusChip)
        topOverlay.contentView.addSubview(flashButton)
        bottomOverlay.contentView.addSubview(shutterButton)

        if let previewLayer {
            cameraContainer.layer.insertSublayer(previewLayer, at: 0)
        }

        setupTopBar()
        setupViewport()
        setupBottomBar()
        setupConstraints()
    }

    private func setupTopBar() {
        topOverlay.clipsToBounds = true
        topOverlay.layer.cornerRadius = 24
        topOverlay.layer.borderWidth = 1
        topOverlay.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        bottomOverlay.clipsToBounds = true
        bottomOverlay.layer.cornerRadius = 30
        bottomOverlay.layer.borderWidth = 1
        bottomOverlay.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        configureChromeButton(closeButton, symbol: "chevron.left")
        closeButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        configureChromeButton(flashButton, symbol: "bolt.badge.automatic.fill")
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)

        let chipLabel = UILabel()
        chipLabel.translatesAutoresizingMaskIntoConstraints = false
        chipLabel.text = "菜品模式"
        chipLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        chipLabel.textColor = UIColor.white.withAlphaComponent(0.94)

        let chipDot = UIView()
        chipDot.translatesAutoresizingMaskIntoConstraints = false
        chipDot.backgroundColor = UIColor(red: 0.44, green: 0.92, blue: 0.55, alpha: 1)
        chipDot.layer.cornerRadius = 4

        statusChip.clipsToBounds = true
        statusChip.layer.cornerRadius = 16
        statusChip.contentView.addSubview(chipDot)
        statusChip.contentView.addSubview(chipLabel)

        NSLayoutConstraint.activate([
            chipDot.leadingAnchor.constraint(equalTo: statusChip.contentView.leadingAnchor, constant: 12),
            chipDot.centerYAnchor.constraint(equalTo: statusChip.contentView.centerYAnchor),
            chipDot.widthAnchor.constraint(equalToConstant: 8),
            chipDot.heightAnchor.constraint(equalToConstant: 8),

            chipLabel.leadingAnchor.constraint(equalTo: chipDot.trailingAnchor, constant: 8),
            chipLabel.trailingAnchor.constraint(equalTo: statusChip.contentView.trailingAnchor, constant: -12),
            chipLabel.centerYAnchor.constraint(equalTo: statusChip.contentView.centerYAnchor)
        ])
    }

    private func setupViewport() {
        cameraContainer.clipsToBounds = false
        cameraContainer.layer.cornerRadius = DishImageSpec.viewportCornerRadius
        cameraContainer.layer.borderWidth = 1
        cameraContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        cameraContainer.layer.shadowColor = UIColor.black.cgColor
        cameraContainer.layer.shadowOpacity = 0.28
        cameraContainer.layer.shadowRadius = 32
        cameraContainer.layer.shadowOffset = CGSize(width: 0, height: 18)

        viewportFrameView.isUserInteractionEnabled = false
        viewportFrameView.layer.borderWidth = 1
        viewportFrameView.layer.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor
        viewportFrameView.backgroundColor = .clear

        gridOverlayView.isUserInteractionEnabled = false
        gridOverlayView.backgroundColor = .clear

        helperLabel.text = "让餐盘尽量居中画面"
        helperLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        helperLabel.textColor = UIColor.white.withAlphaComponent(0.96)
    }

    private func setupBottomBar() {
        shutterButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        shutterButton.layer.cornerRadius = DishImageSpec.shutterOuterDiameter / 2
        shutterButton.layer.borderWidth = 1
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)

        shutterInnerView.backgroundColor = UIColor.white
        shutterInnerView.layer.cornerRadius = DishImageSpec.shutterInnerDiameter / 2
        shutterInnerView.isUserInteractionEnabled = false
        shutterButton.addSubview(shutterInnerView)
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            topOverlay.topAnchor.constraint(equalTo: safe.topAnchor, constant: 10),
            topOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            topOverlay.heightAnchor.constraint(equalToConstant: 64),

            closeButton.leadingAnchor.constraint(equalTo: topOverlay.contentView.leadingAnchor, constant: 10),
            closeButton.centerYAnchor.constraint(equalTo: topOverlay.contentView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            statusChip.centerXAnchor.constraint(equalTo: topOverlay.contentView.centerXAnchor),
            statusChip.centerYAnchor.constraint(equalTo: topOverlay.contentView.centerYAnchor),
            statusChip.heightAnchor.constraint(equalToConstant: 32),

            flashButton.trailingAnchor.constraint(equalTo: topOverlay.contentView.trailingAnchor, constant: -10),
            flashButton.centerYAnchor.constraint(equalTo: topOverlay.contentView.centerYAnchor),
            flashButton.widthAnchor.constraint(equalToConstant: 44),
            flashButton.heightAnchor.constraint(equalToConstant: 44),

            bottomOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bottomOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomOverlay.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -14),
            bottomOverlay.heightAnchor.constraint(equalToConstant: 116),

            cameraContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 16),
            cameraContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DishImageSpec.viewportHorizontalInset),
            cameraContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DishImageSpec.viewportHorizontalInset),
            cameraContainer.heightAnchor.constraint(equalTo: cameraContainer.widthAnchor, multiplier: 1 / DishImageSpec.viewportAspectRatio),
            cameraContainer.topAnchor.constraint(greaterThanOrEqualTo: topOverlay.bottomAnchor, constant: 18),
            cameraContainer.bottomAnchor.constraint(lessThanOrEqualTo: bottomOverlay.topAnchor, constant: -18),

            viewportFrameView.leadingAnchor.constraint(equalTo: cameraContainer.leadingAnchor),
            viewportFrameView.trailingAnchor.constraint(equalTo: cameraContainer.trailingAnchor),
            viewportFrameView.topAnchor.constraint(equalTo: cameraContainer.topAnchor),
            viewportFrameView.bottomAnchor.constraint(equalTo: cameraContainer.bottomAnchor),

            gridOverlayView.leadingAnchor.constraint(equalTo: cameraContainer.leadingAnchor),
            gridOverlayView.trailingAnchor.constraint(equalTo: cameraContainer.trailingAnchor),
            gridOverlayView.topAnchor.constraint(equalTo: cameraContainer.topAnchor),
            gridOverlayView.bottomAnchor.constraint(equalTo: cameraContainer.bottomAnchor),

            helperLabel.leadingAnchor.constraint(equalTo: cameraContainer.leadingAnchor, constant: 14),
            helperLabel.trailingAnchor.constraint(lessThanOrEqualTo: cameraContainer.trailingAnchor, constant: -14),
            helperLabel.bottomAnchor.constraint(equalTo: cameraContainer.bottomAnchor, constant: -14),

            shutterButton.centerXAnchor.constraint(equalTo: bottomOverlay.contentView.centerXAnchor),
            shutterButton.centerYAnchor.constraint(equalTo: bottomOverlay.contentView.centerYAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: DishImageSpec.shutterOuterDiameter),
            shutterButton.heightAnchor.constraint(equalToConstant: DishImageSpec.shutterOuterDiameter),

            shutterInnerView.centerXAnchor.constraint(equalTo: shutterButton.centerXAnchor),
            shutterInnerView.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            shutterInnerView.widthAnchor.constraint(equalToConstant: DishImageSpec.shutterInnerDiameter),
            shutterInnerView.heightAnchor.constraint(equalToConstant: DishImageSpec.shutterInnerDiameter)
        ])
    }

    private func configureChromeButton(_ button: UIButton, symbol: String) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol)
        config.baseForegroundColor = .white
        config.background.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        config.background.cornerRadius = 22
        button.configuration = config
    }

    private func updateFlashButtonAppearance() {
        var symbolName: String
        var tint = UIColor.white

        switch flashMode {
        case .auto:
            symbolName = "bolt.badge.automatic.fill"
            tint = UIColor.white.withAlphaComponent(0.95)
        case .on:
            symbolName = "bolt.fill"
            tint = UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 1)
        case .off:
            symbolName = "bolt.slash.fill"
            tint = UIColor.white.withAlphaComponent(0.85)
        @unknown default:
            symbolName = "bolt.badge.automatic.fill"
        }

        flashButton.configuration?.image = UIImage(systemName: symbolName)
        flashButton.configuration?.baseForegroundColor = tint
    }

    @objc private func cancelTapped() {
        onCancel()
    }

    @objc private func flashTapped() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        case .off:
            flashMode = .auto
        @unknown default:
            flashMode = .auto
        }
        updateFlashButtonAppearance()
    }

    @objc private func shutterTapped() {
        let animator = UIViewPropertyAnimator(duration: 0.14, curve: .easeOut) {
            self.shutterButton.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.shutterInnerView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
        animator.addCompletion { _ in
            UIView.animate(withDuration: 0.18) {
                self.shutterButton.transform = .identity
                self.shutterInnerView.transform = .identity
            }
        }
        animator.startAnimation()

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

private final class DishCameraGridView: UIView {
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.18).cgColor)
        context.setLineWidth(1)

        let thirdsX = [rect.width / 3, rect.width * 2 / 3]
        let thirdsY = [rect.height / 3, rect.height * 2 / 3]

        for x in thirdsX {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: rect.height))
        }

        for y in thirdsY {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: rect.width, y: y))
        }

        context.strokePath()
    }
}
