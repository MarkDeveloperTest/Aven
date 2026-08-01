import Foundation
import Testing
@testable import Aven

@Suite("Pairing QR payload")
struct PairingQRCodePayloadTests {
    private let linkToken = String(repeating: "a", count: 40)
        + "."
        + String(repeating: "B", count: 43)

    @Test("Encodes the development universal link")
    func encodesUniversalLink() {
        #expect(
            PairingQRCodePayload.makePayload(
                linkToken: linkToken,
                environment: .development
            ) == "https://aven-ios-dev-4f7c2.web.app/invite/\(linkToken)"
        )
        #expect(
            PairingQRCodePayload.makePayload(
                linkToken: linkToken,
                environment: .staging
            ) == nil
        )
        #expect(
            PairingQRCodePayload.makePayload(
                linkToken: linkToken,
                environment: .production
            ) == nil
        )
    }

    @Test("Parses only the exact environment host and invitation path")
    func parsesCanonicalPayload() throws {
        let payload = try #require(
            PairingQRCodePayload.makePayload(
                linkToken: linkToken,
                environment: .development
            )
        )

        #expect(
            PairingQRCodePayload.parse(
                payload,
                environment: .development
            ) == linkToken
        )
        #expect(
            PairingQRCodePayload.parse(
                payload,
                environment: .production
            ) == nil
        )
    }

    @Test("Rejects noncanonical and cross-environment URLs")
    func rejectsNoncanonicalScannerPayloads() {
        let rejectedPayloads = [
            linkToken,
            "http://aven-ios-dev-4f7c2.web.app/invite/\(linkToken)",
            "https://example.com/invite/\(linkToken)",
            "https://aven-ios-dev-4f7c2.web.app/wrong/\(linkToken)",
            "https://aven-ios-dev-4f7c2.web.app/invite/\(linkToken)?extra=1",
            "https://aven-ios-dev-4f7c2.web.app/invite/\(linkToken)#fragment",
        ]

        for payload in rejectedPayloads {
            #expect(
                PairingQRCodePayload.parse(
                    payload,
                    environment: .development
                ) == nil
            )
        }
    }

    @Test("Manual entry normalizes case, spaces, and hyphens")
    func validatesManualEntry() {
        #expect(PairingQRCodePayload.parseManualEntry(" abc-7k9 ") == "ABC7K9")
        #expect(PairingQRCodePayload.parseManualEntry("O0I1AA") == nil)
        #expect(PairingQRCodePayload.parseManualEntry("ABC7K") == nil)
        #expect(PairingInvitation.isValidLinkToken(linkToken))
        #expect(PairingInvitation.isValidManualCode("abc-7k9"))
    }
}
