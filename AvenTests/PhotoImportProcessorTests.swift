import Foundation
import Testing
@testable import Aven

@Suite("Photo import")
struct PhotoImportProcessorTests {
    @Test("Missing and empty transfers are rejected")
    func rejectsMissingData() {
        #expect(throws: PhotoImportProcessor.ImportError.emptyData) {
            try PhotoImportProcessor.makeUploadThumbnail(from: nil)
        }
        #expect(throws: PhotoImportProcessor.ImportError.emptyData) {
            try PhotoImportProcessor.makeUploadThumbnail(from: Data())
        }
    }

    @Test("Arbitrary bytes are not accepted as an image")
    func rejectsUnsupportedImage() {
        #expect(throws: PhotoImportProcessor.ImportError.unsupportedImage) {
            try PhotoImportProcessor.makeUploadThumbnail(
                from: Data("not-an-image".utf8)
            )
        }
    }
}
