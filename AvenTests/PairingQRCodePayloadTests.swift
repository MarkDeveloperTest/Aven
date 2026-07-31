import Testing
@testable import Aven

@Suite("Pairing QR payload")
struct PairingQRCodePayloadTests {
    private let invitationCode = String(repeating: "a", count: 40)
        + "."
        + String(repeating: "B", count: 43)

    @Test("Encodes a canonical environment-bound payload")
    func encodesCanonicalPayload() {
        #expect(
            PairingQRCodePayload.makePayload(
                invitationCode: invitationCode,
                environment: .development
            ) == "aven-dev://pair?v=1&code=\(invitationCode)"
        )
        #expect(
            PairingQRCodePayload.makePayload(
                invitationCode: invitationCode,
                environment: .staging
            ) == "aven-staging://pair?v=1&code=\(invitationCode)"
        )
        #expect(
            PairingQRCodePayload.makePayload(
                invitationCode: invitationCode,
                environment: .production
            ) == "aven://pair?v=1&code=\(invitationCode)"
        )
    }

    @Test("Parses only the matching canonical scanner payload")
    func parsesCanonicalPayload() throws {
        let payload = try #require(
            PairingQRCodePayload.makePayload(
                invitationCode: invitationCode,
                environment: .development
            )
        )

        #expect(
            PairingQRCodePayload.parse(
                payload,
                environment: .development
            ) == invitationCode
        )
        #expect(
            PairingQRCodePayload.parse(
                payload,
                environment: .production
            ) == nil
        )
    }

    @Test("Rejects raw codes and noncanonical scanner URLs")
    func rejectsNoncanonicalScannerPayloads() {
        let rejectedPayloads = [
            invitationCode,
            "aven-dev://wrong?v=1&code=\(invitationCode)",
            "aven-dev://pair?v=2&code=\(invitationCode)",
            "aven-dev://pair?code=\(invitationCode)&v=1",
            "aven-dev://pair?v=1&code=\(invitationCode)&extra=1",
            "aven-dev://pair/path?v=1&code=\(invitationCode)",
            "aven-dev://pair?v=1&code=\(invitationCode)#fragment",
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

    @Test("Manual entry accepts only a raw exact backend token")
    func validatesManualEntry() {
        #expect(
            PairingQRCodePayload.parseManualEntry("  \(invitationCode)\n")
                == invitationCode
        )
        #expect(
            PairingQRCodePayload.parseManualEntry(
                "aven-dev://pair?v=1&code=\(invitationCode)"
            ) == nil
        )
    }

    @Test("Validates the exact backend token alphabet and length")
    func validatesBackendTokenContract() {
        #expect(PairingQRCodePayload.isValidInvitationCode(invitationCode))
        #expect(
            PairingQRCodePayload.isValidInvitationCode(
                String(repeating: "A", count: 40)
                    + "."
                    + String(repeating: "B", count: 43)
            ) == false
        )
        #expect(
            PairingQRCodePayload.isValidInvitationCode(
                String(repeating: "a", count: 40)
                    + "."
                    + String(repeating: "+", count: 43)
            ) == false
        )
        #expect(
            PairingQRCodePayload.isValidInvitationCode(
                String(repeating: "a", count: 40)
                    + "."
                    + String(repeating: "B", count: 42)
            ) == false
        )
    }
}
