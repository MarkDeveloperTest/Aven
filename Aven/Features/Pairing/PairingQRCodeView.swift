@preconcurrency import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct PairingQRCodeView: View {
    @Environment(\.displayScale) private var displayScale
    @State private var renderedCode: RenderedPairingQRCode?

    private let quietZone: CGFloat = 18
    private let payload: String
    private let size: CGFloat

    init(
        payload: String,
        size: CGFloat = 176
    ) {
        self.payload = payload
        self.size = size
    }

    var body: some View {
        Group {
            if let renderedCode {
                Image(uiImage: renderedCode.image)
                    .resizable()
                    .interpolation(.none)
                    .frame(
                        width: renderedCode.pointSize,
                        height: renderedCode.pointSize
                    )
            } else {
                ProgressView()
                    .tint(PremiumArrivalStyle.pinkInk)
            }
        }
        .frame(width: size, height: size)
        .background(.white)
        .clipShape(.rect(cornerRadius: AvenRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AvenRadius.control, style: .continuous)
                .stroke(PremiumArrivalStyle.divider, lineWidth: 0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("pairing.scan.qr.accessibility"))
        .accessibilityHint(Text("pairing.scan.qr.hint"))
        .task(id: renderRequest) {
            renderedCode = await PairingQRCodeRenderer.shared.render(
                payload: payload,
                maximumPointSize: max(size - quietZone * 2, 1),
                displayScale: displayScale
            )
        }
    }

    private var renderRequest: PairingQRCodeRenderRequest {
        PairingQRCodeRenderRequest(
            payload: payload,
            maximumPointSize: max(size - quietZone * 2, 1),
            displayScale: displayScale
        )
    }
}

private struct PairingQRCodeRenderRequest: Hashable, Sendable {
    let payload: String
    let maximumPointSize: CGFloat
    let displayScale: CGFloat
}

private struct RenderedPairingQRCode: @unchecked Sendable {
    let image: UIImage
    let pointSize: CGFloat
}

private actor PairingQRCodeRenderer {
    static let shared = PairingQRCodeRenderer()

    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private var cache: [PairingQRCodeRenderRequest: RenderedPairingQRCode] = [:]

    func render(
        payload: String,
        maximumPointSize: CGFloat,
        displayScale: CGFloat
    ) -> RenderedPairingQRCode? {
        let request = PairingQRCodeRenderRequest(
            payload: payload,
            maximumPointSize: maximumPointSize,
            displayScale: displayScale
        )
        if let cached = cache[request] {
            return cached
        }
        guard AppBuildEnvironment.allCases.contains(where: { environment in
            PairingQRCodePayload.parse(payload, environment: environment) != nil
        }) else {
            return nil
        }

        let generator = CIFilter.qrCodeGenerator()
        generator.message = Data(payload.utf8)
        generator.correctionLevel = "M"
        guard let generatedImage = generator.outputImage else { return nil }

        let falseColor = CIFilter.falseColor()
        falseColor.inputImage = generatedImage
        falseColor.color0 = CIColor.black
        falseColor.color1 = CIColor.white
        guard let opaqueImage = falseColor.outputImage else { return nil }

        let screenScale = max(displayScale, 1)
        let pixelScale = max(
            floor(maximumPointSize * screenScale / opaqueImage.extent.width),
            1
        )
        let scaledImage = opaqueImage.transformed(
            by: CGAffineTransform(scaleX: pixelScale, y: pixelScale)
        )
        guard let cgImage = context.createCGImage(
            scaledImage,
            from: scaledImage.extent.integral
        ) else {
            return nil
        }

        let rendered = RenderedPairingQRCode(
            image: UIImage(cgImage: cgImage, scale: screenScale, orientation: .up),
            pointSize: scaledImage.extent.width / screenScale
        )
        if cache.count >= 16 {
            cache.removeAll(keepingCapacity: true)
        }
        cache[request] = rendered
        return rendered
    }
}
