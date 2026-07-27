import Testing
@testable import Aven

@Suite("Secure nonce")
struct SecureNonceGeneratorTests {
    @Test("Generates the requested length and hashes deterministically")
    func generatesAndHashes() throws {
        let nonce = try SecureNonceGenerator.make(length: 48)

        #expect(nonce.count == 48)
        #expect(
            SecureNonceGenerator.sha256("Aven") ==
                "497a955a72b46865a25b48207c091cbe28f2b766c76336f38976fa47bb12e569"
        )
    }
}
