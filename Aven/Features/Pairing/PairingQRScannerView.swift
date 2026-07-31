@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct PairingQRScannerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private let environment: AppBuildEnvironment
    private let onScanned: (String) -> Void

    @State private var accessState = CameraAccessState.checking
    @State private var hasDeliveredCode = false
    @State private var isManualEntryVisible = false
    @State private var isTorchAvailable = false
    @State private var isTorchOn = false
    @State private var manualEntry = ""
    @State private var showsManualEntryError = false
    @AccessibilityFocusState private var accessibilityFocus: AccessibilityFocus?

    init(
        environment: AppBuildEnvironment = .current,
        onScanned: @escaping (String) -> Void
    ) {
        self.environment = environment
        self.onScanned = onScanned
    }

    var body: some View {
        Group {
            switch accessState {
            case .checking:
                checkingView
            case .authorized:
                scannerView
            case .denied:
                fallbackView(
                    systemImage: "camera.fill",
                    title: "pairing.scan.permission.denied.title",
                    message: "pairing.scan.permission.denied.message",
                    showsSettingsAction: true
                )
            case .restricted:
                fallbackView(
                    systemImage: "camera.fill",
                    title: "pairing.scan.permission.restricted.title",
                    message: "pairing.scan.permission.restricted.message",
                    showsSettingsAction: false
                )
            case .unavailable:
                fallbackView(
                    systemImage: "camera.slash.fill",
                    title: "pairing.scan.unavailable.title",
                    message: "pairing.scan.unavailable.message",
                    showsSettingsAction: false
                )
            }
        }
        .preferredColorScheme(.light)
        .task {
            await refreshCameraAccess(requestIfNeeded: true)
            accessibilityFocus = .heading
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshCameraAccess(requestIfNeeded: false) }
            } else {
                isTorchOn = false
            }
        }
        .onDisappear {
            manualEntry = ""
            isTorchOn = false
        }
    }

    private var checkingView: some View {
        ZStack {
            PremiumArrivalBackground()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(PremiumArrivalStyle.pinkInk)
                Text("pairing.scan.permission.checking")
                    .font(.body)
                    .foregroundStyle(PremiumArrivalStyle.mutedInk)
            }
        }
        .overlay(alignment: .topTrailing) {
            closeButton(darkBackground: false)
                .padding(20)
        }
    }

    private var scannerView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PairingCameraPreview(
                environment: environment,
                isRunning: scenePhase == .active && hasDeliveredCode == false,
                torchEnabled: isTorchOn,
                onScanned: receiveScannedCode,
                onUnavailable: {
                    accessState = .unavailable
                    isTorchOn = false
                },
                onTorchAvailabilityChanged: { isAvailable in
                    isTorchAvailable = isAvailable
                    if isAvailable == false {
                        isTorchOn = false
                    }
                }
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            PairingScannerFrame(reduceMotion: reduceMotion)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
        .overlay(alignment: .top) {
            scannerToolbar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            scannerInstructions
        }
    }

    private var scannerToolbar: some View {
        HStack(spacing: 12) {
            Text("AVEN")
                .font(.system(size: 16, weight: .medium))
                .tracking(6)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Spacer()

            if isTorchAvailable {
                Button {
                    isTorchOn.toggle()
                } label: {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(.white)
                .background(toolbarButtonBackground, in: .circle)
                .accessibilityLabel(
                    Text(isTorchOn ? "pairing.scan.torch.off" : "pairing.scan.torch.on")
                )
                .accessibilityIdentifier("pairing.scan.torch")
            }

            closeButton(darkBackground: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var scannerInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "viewfinder")
                    .foregroundStyle(PremiumArrivalStyle.pinkInk)
                    .accessibilityHidden(true)

                Text("pairing.scan.title")
                    .font(.system(.title2, design: .serif, weight: .medium))
                    .foregroundStyle(PremiumArrivalStyle.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($accessibilityFocus, equals: .heading)
            }

            Text("pairing.scan.instructions")
                .font(.body)
                .lineSpacing(3)
                .foregroundStyle(PremiumArrivalStyle.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            if hasDeliveredCode {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("pairing.scan.connecting")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(PremiumArrivalStyle.ink)
                .accessibilityElement(children: .combine)
            } else {
                manualEntryDisclosure
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(
            reduceTransparency ? Color.white : Color.white.opacity(0.96)
        )
    }

    private var manualEntryDisclosure: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    isManualEntryVisible.toggle()
                    showsManualEntryError = false
                }
            } label: {
                HStack {
                    Text("pairing.scan.manual.action")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: isManualEntryVisible ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(PremiumArrivalStyle.ink)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pairing.scan.manual.toggle")

            if isManualEntryVisible {
                manualEntryForm
                    .transition(.opacity)
            }
        }
    }

    private var manualEntryForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            SecureField("pairing.scan.manual.placeholder", text: $manualEntry)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .submitLabel(.go)
                .onSubmit(submitManualEntry)
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(
                    PremiumArrivalStyle.blush.opacity(0.34),
                    in: .rect(cornerRadius: AvenRadius.control, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: AvenRadius.control,
                        style: .continuous
                    )
                    .stroke(
                        showsManualEntryError
                            ? Color.red.opacity(0.72)
                            : PremiumArrivalStyle.divider,
                        lineWidth: 1
                    )
                }
                .accessibilityIdentifier("pairing.scan.manual.field")

            if showsManualEntryError {
                Text("pairing.scan.manual.invalid")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityFocused($accessibilityFocus, equals: .manualError)
            }

            Button("pairing.scan.manual.connect", action: submitManualEntry)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(
                    PremiumArrivalStyle.ink,
                    in: .rect(cornerRadius: AvenRadius.control, style: .continuous)
                )
                .disabled(manualEntry.isEmpty)
                .opacity(manualEntry.isEmpty ? 0.55 : 1)
                .accessibilityIdentifier("pairing.scan.manual.connect")
        }
    }

    private func fallbackView(
        systemImage: String,
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        showsSettingsAction: Bool
    ) -> some View {
        ZStack {
            PremiumArrivalBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: systemImage)
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(PremiumArrivalStyle.pinkInk)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 14) {
                        Text(title)
                            .font(.system(.largeTitle, design: .serif, weight: .regular))
                            .foregroundStyle(PremiumArrivalStyle.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($accessibilityFocus, equals: .heading)

                        Text(message)
                            .font(.body)
                            .lineSpacing(3)
                            .foregroundStyle(PremiumArrivalStyle.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if showsSettingsAction {
                        Button("pairing.scan.permission.settings") {
                            guard let settingsURL = URL(
                                string: UIApplication.openSettingsURLString
                            ) else {
                                return
                            }
                            openURL(settingsURL)
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                        .background(
                            PremiumArrivalStyle.ink,
                            in: .rect(
                                cornerRadius: AvenRadius.control,
                                style: .continuous
                            )
                        )
                        .accessibilityIdentifier("pairing.scan.open-settings")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("pairing.scan.manual.title")
                            .font(.headline)
                            .foregroundStyle(PremiumArrivalStyle.ink)
                        manualEntryForm
                    }
                    .padding(18)
                    .avenGlassSurface()
                }
                .padding(.horizontal, 26)
                .padding(.top, 128)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .overlay(alignment: .topTrailing) {
            closeButton(darkBackground: false)
                .padding(20)
        }
    }

    private var toolbarButtonBackground: Color {
        reduceTransparency ? Color.black.opacity(0.84) : Color.black.opacity(0.46)
    }

    private func closeButton(darkBackground: Bool) -> some View {
        Button(action: cancel) {
            Image(systemName: "xmark")
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(darkBackground ? Color.white : PremiumArrivalStyle.ink)
        .background(
            darkBackground ? toolbarButtonBackground : Color.white.opacity(0.92),
            in: .circle
        )
        .overlay {
            Circle()
                .stroke(
                    darkBackground ? Color.white.opacity(0.24) : PremiumArrivalStyle.divider,
                    lineWidth: 0.75
                )
        }
        .accessibilityLabel(Text("action.cancel"))
        .accessibilityIdentifier("pairing.scan.cancel")
    }

    @MainActor
    private func refreshCameraAccess(requestIfNeeded: Bool) async {
        guard hasDeliveredCode == false else { return }

        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorizationStatus {
        case .authorized:
            accessState = hasBackCamera ? .authorized : .unavailable
        case .notDetermined where requestIfNeeded:
            accessState = .checking
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard Task.isCancelled == false else { return }
            accessState = granted && hasBackCamera ? .authorized : .denied
        case .notDetermined:
            accessState = .checking
        case .denied:
            accessState = .denied
        case .restricted:
            accessState = .restricted
        @unknown default:
            accessState = .unavailable
        }
    }

    private var hasBackCamera: Bool {
        AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) != nil
    }

    @MainActor
    private func receiveScannedCode(_ invitationCode: String) {
        deliver(invitationCode)
    }

    @MainActor
    private func submitManualEntry() {
        guard let invitationCode = PairingQRCodePayload.parseManualEntry(manualEntry) else {
            showsManualEntryError = true
            accessibilityFocus = .manualError
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        deliver(invitationCode)
    }

    @MainActor
    private func deliver(_ invitationCode: String) {
        guard hasDeliveredCode == false else { return }
        hasDeliveredCode = true
        manualEntry = ""
        isTorchOn = false
        showsManualEntryError = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(
            notification: .announcement,
            argument: String(localized: "pairing.scan.connecting")
        )
        onScanned(invitationCode)
        dismiss()
    }

    @MainActor
    private func cancel() {
        manualEntry = ""
        isTorchOn = false
        dismiss()
    }
}

private enum CameraAccessState: Equatable {
    case checking
    case authorized
    case denied
    case restricted
    case unavailable
}

private enum AccessibilityFocus: Hashable {
    case heading
    case manualError
}

private struct PairingScannerFrame: View {
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            let scanSize = min(max(geometry.size.width - 72, 220), 284)
            let center = CGPoint(
                x: geometry.size.width / 2,
                y: max(scanSize / 2 + 112, geometry.size.height * 0.42)
            )
            let scanRect = CGRect(
                x: center.x - scanSize / 2,
                y: center.y - scanSize / 2,
                width: scanSize,
                height: scanSize
            )

            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    path.addRoundedRect(
                        in: scanRect,
                        cornerSize: CGSize(width: 24, height: 24)
                    )
                }
                .fill(
                    Color.black.opacity(0.46),
                    style: FillStyle(eoFill: true)
                )

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.92), lineWidth: 1)
                    .frame(width: scanSize, height: scanSize)
                    .position(center)

                PairingScannerCorners(size: scanSize)
                    .stroke(
                        PremiumArrivalStyle.blush,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: scanSize, height: scanSize)
                    .position(center)

                if reduceMotion == false {
                    PairingScannerLine(size: scanSize)
                        .position(center)
                }
            }
        }
    }
}

private struct PairingScannerCorners: Shape {
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        let length = min(size * 0.16, 42)
        let inset: CGFloat = 2.5
        let minX = rect.minX + inset
        let maxX = rect.maxX - inset
        let minY = rect.minY + inset
        let maxY = rect.maxY - inset
        var path = Path()

        path.move(to: CGPoint(x: minX, y: minY + length))
        path.addLine(to: CGPoint(x: minX, y: minY))
        path.addLine(to: CGPoint(x: minX + length, y: minY))

        path.move(to: CGPoint(x: maxX - length, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: minY + length))

        path.move(to: CGPoint(x: maxX, y: maxY - length))
        path.addLine(to: CGPoint(x: maxX, y: maxY))
        path.addLine(to: CGPoint(x: maxX - length, y: maxY))

        path.move(to: CGPoint(x: minX + length, y: maxY))
        path.addLine(to: CGPoint(x: minX, y: maxY))
        path.addLine(to: CGPoint(x: minX, y: maxY - length))
        return path
    }
}

private struct PairingScannerLine: View {
    let size: CGFloat
    @State private var isAtBottom = false

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, PremiumArrivalStyle.blush, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size - 30, height: 2)
            .shadow(color: PremiumArrivalStyle.blush.opacity(0.9), radius: 5)
            .offset(y: isAtBottom ? size / 2 - 20 : -size / 2 + 20)
            .onAppear {
                withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: true)) {
                    isAtBottom = true
                }
            }
    }
}

private struct PairingCameraPreview: UIViewRepresentable {
    let environment: AppBuildEnvironment
    let isRunning: Bool
    let torchEnabled: Bool
    let onScanned: (String) -> Void
    let onUnavailable: () -> Void
    let onTorchAvailabilityChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(environment: environment)
    }

    func makeUIView(context: Context) -> PairingCameraPreviewView {
        let view = PairingCameraPreviewView()
        view.previewLayer.session = context.coordinator.captureController.session
        context.coordinator.updateCallbacks(from: self)
        return view
    }

    func updateUIView(_ uiView: PairingCameraPreviewView, context: Context) {
        context.coordinator.updateCallbacks(from: self)
        if isRunning {
            context.coordinator.captureController.start()
            context.coordinator.captureController.setTorch(enabled: torchEnabled)
        } else {
            context.coordinator.captureController.stop()
        }
    }

    static func dismantleUIView(
        _ uiView: PairingCameraPreviewView,
        coordinator: Coordinator
    ) {
        uiView.previewLayer.session = nil
        coordinator.captureController.teardown()
    }

    @MainActor
    final class Coordinator {
        let callbackRelay: PairingScannerCallbackRelay
        let captureController: PairingCaptureSessionController

        init(environment: AppBuildEnvironment) {
            let callbackRelay = PairingScannerCallbackRelay()
            self.callbackRelay = callbackRelay
            captureController = PairingCaptureSessionController(
                environment: environment,
                callbackRelay: callbackRelay
            )
        }

        func updateCallbacks(from preview: PairingCameraPreview) {
            callbackRelay.onScanned = preview.onScanned
            callbackRelay.onUnavailable = preview.onUnavailable
            callbackRelay.onTorchAvailabilityChanged =
                preview.onTorchAvailabilityChanged
        }
    }
}

@MainActor
private final class PairingCameraPreviewView: UIView {
    override static var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("Pairing camera preview layer is unavailable")
        }
        return previewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard
            let connection = previewLayer.connection,
            let interfaceOrientation = window?.windowScene?.effectiveGeometry
                .interfaceOrientation
        else {
            return
        }

        let rotationAngle: CGFloat = switch interfaceOrientation {
        case .portrait:
            90
        case .portraitUpsideDown:
            270
        case .landscapeLeft:
            180
        case .landscapeRight:
            0
        default:
            90
        }

        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }
}

@MainActor
private final class PairingScannerCallbackRelay {
    var onScanned: (String) -> Void = { _ in }
    var onUnavailable: () -> Void = {}
    var onTorchAvailabilityChanged: (Bool) -> Void = { _ in }
}

// All mutable capture state is confined to sessionQueue. Only callback delivery
// crosses to the main actor through PairingScannerCallbackRelay.
private final class PairingCaptureSessionController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    private let callbackRelay: PairingScannerCallbackRelay
    private let environment: AppBuildEnvironment
    private let sessionQueue = DispatchQueue(
        label: "com.aven.pairing.qr-scanner-session",
        qos: .userInitiated
    )
    private var cameraDevice: AVCaptureDevice?
    private var configurationFailed = false
    private var didDeliverCode = false
    private var isConfigured = false
    private var metadataOutput: AVCaptureMetadataOutput?

    init(
        environment: AppBuildEnvironment,
        callbackRelay: PairingScannerCallbackRelay
    ) {
        self.environment = environment
        self.callbackRelay = callbackRelay
        super.init()
    }

    func start() {
        sessionQueue.async { [self] in
            if isConfigured == false && configurationFailed == false {
                configure()
            }
            guard isConfigured, session.isRunning == false else { return }
            didDeliverCode = false
            session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            setTorchOnQueue(enabled: false)
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func setTorch(enabled: Bool) {
        sessionQueue.async { [self] in
            setTorchOnQueue(enabled: enabled)
        }
    }

    func teardown() {
        sessionQueue.async { [self] in
            setTorchOnQueue(enabled: false)
            if session.isRunning {
                session.stopRunning()
            }
            metadataOutput?.setMetadataObjectsDelegate(nil, queue: nil)
        }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        guard let cameraDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            failConfiguration()
            return
        }

        do {
            let cameraInput = try AVCaptureDeviceInput(device: cameraDevice)
            guard session.canAddInput(cameraInput) else {
                failConfiguration()
                return
            }
            session.addInput(cameraInput)
        } catch {
            failConfiguration()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else {
            failConfiguration()
            return
        }
        session.addOutput(metadataOutput)

        guard metadataOutput.availableMetadataObjectTypes.contains(.qr) else {
            failConfiguration()
            return
        }

        metadataOutput.setMetadataObjectsDelegate(self, queue: sessionQueue)
        metadataOutput.metadataObjectTypes = [.qr]
        self.cameraDevice = cameraDevice
        self.metadataOutput = metadataOutput
        isConfigured = true
        reportTorchAvailability(cameraDevice.hasTorch)
    }

    private func failConfiguration() {
        configurationFailed = true
        Task { @MainActor [callbackRelay] in
            callbackRelay.onUnavailable()
        }
    }

    private func reportTorchAvailability(_ isAvailable: Bool) {
        Task { @MainActor [callbackRelay] in
            callbackRelay.onTorchAvailabilityChanged(isAvailable)
        }
    }

    private func setTorchOnQueue(enabled: Bool) {
        guard
            let cameraDevice,
            cameraDevice.hasTorch,
            cameraDevice.isTorchModeSupported(enabled ? .on : .off)
        else {
            return
        }

        do {
            try cameraDevice.lockForConfiguration()
            cameraDevice.torchMode = enabled ? .on : .off
            cameraDevice.unlockForConfiguration()
        } catch {
            reportTorchAvailability(false)
        }
    }
}

extension PairingCaptureSessionController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard didDeliverCode == false else { return }

        for metadataObject in metadataObjects {
            guard
                let codeObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                codeObject.type == .qr,
                let payload = codeObject.stringValue,
                let invitationCode = PairingQRCodePayload.parse(
                    payload,
                    environment: environment
                )
            else {
                continue
            }

            didDeliverCode = true
            setTorchOnQueue(enabled: false)
            if session.isRunning {
                session.stopRunning()
            }

            Task { @MainActor [callbackRelay] in
                callbackRelay.onScanned(invitationCode)
            }
            return
        }
    }
}
