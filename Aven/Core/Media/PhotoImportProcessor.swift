import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum PhotoImportProcessor {
    enum ImportError: Error, Equatable {
        case emptyData
        case fileTooLarge
        case unsupportedImage
        case encodingFailed
    }

    private static let maximumInputBytes = 25 * 1_024 * 1_024
    private static let maximumPixelDimension = 1_600

    static func makeUploadThumbnail(from data: Data?) throws -> Data {
        guard let data, data.isEmpty == false else {
            throw ImportError.emptyData
        }
        guard data.count <= maximumInputBytes else {
            throw ImportError.fileTooLarge
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImportError.unsupportedImage
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            throw ImportError.unsupportedImage
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImportError.encodingFailed
        }

        CGImageDestinationAddImage(
            destination,
            thumbnail,
            [kCGImageDestinationLossyCompressionQuality: 0.84] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw ImportError.encodingFailed
        }
        return output as Data
    }
}
