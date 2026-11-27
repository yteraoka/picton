import Foundation
import ImageIO
import Testing
import UIKit
@testable import Picton

/// #52: 外部から来た画像の検証・縮小デコード
@Suite("ImageStorageService")
struct ImageStorageServiceTests {
    private func pixelSize(_ image: UIImage) -> CGSize {
        CGSize(width: image.cgImage!.width, height: image.cgImage!.height)
    }

    // MARK: - sanitizedImage

    @Test func rejectsNonImageData() {
        #expect(ImageStorageService.sanitizedImage(from: Data("hello".utf8)) == nil)
        #expect(ImageStorageService.sanitizedImage(from: Data()) == nil)
    }

    @Test func rejectsDecompressionBombWithoutDecoding() throws {
        let bomb = TestImages.compressionBombPNG(width: 8000, height: 8000)
        #expect(bomb.count < 16 * 1024)
        // 有効な画像として ImageIO がサイズを読めていること（＝弾いているのはピクセル数の上限）を確認
        let properties = try #require(TestImages.properties(of: bomb))
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 8000)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 8000)

        #expect(ImageStorageService.sanitizedImage(from: bomb) == nil)
    }

    @Test func compressionBombHelperProducesDecodableImage() throws {
        // 同じ作り方の小さい画像が実際にデコードできる＝ヘルパーが有効な PNG を作っている
        let small = try #require(ImageStorageService.sanitizedImage(
            from: TestImages.compressionBombPNG(width: 100, height: 100)
        ))
        #expect(pixelSize(small) == CGSize(width: 100, height: 100))
    }

    @Test func pixelCountLimitIsApplied() {
        let jpeg = TestImages.jpeg(width: 2000, height: 1000)
        #expect(ImageStorageService.sanitizedImage(from: jpeg, maxSourcePixelCount: 1_999_999) == nil)
        #expect(ImageStorageService.sanitizedImage(from: jpeg, maxSourcePixelCount: 2_000_000) != nil)
    }

    @Test func allowsTypicalPhotoResolution() {
        // iPhone の 48MP 写真（8064×6048）は上限内
        #expect(8064 * 6048 <= ImageStorageService.maxSourcePixelCount)
    }

    @Test func downsamplesLargeImageKeepingAspectRatio() throws {
        let image = try #require(ImageStorageService.sanitizedImage(from: TestImages.jpeg(width: 3000, height: 1500)))
        let size = pixelSize(image)
        #expect(max(size.width, size.height) == CGFloat(ImageStorageService.maxDecodedPixelSize))
        #expect(abs(size.width / size.height - 2) < 0.01)
    }

    @Test func doesNotUpscaleSmallImage() throws {
        let image = try #require(ImageStorageService.sanitizedImage(from: TestImages.jpeg(width: 120, height: 80)))
        #expect(pixelSize(image) == CGSize(width: 120, height: 80))
    }

    @Test func savingSanitizedImageStripsLocationMetadata() throws {
        let original = TestImages.jpeg(width: 800, height: 800, withGPS: true)
        #expect(TestImages.properties(of: original)?[kCGImagePropertyGPSDictionary] != nil)

        let id = UUID()
        defer { ImageStorageService.delete(id: id) }
        let image = try #require(ImageStorageService.sanitizedImage(from: original))
        let url = try ImageStorageService.save(image: image, id: id)

        let stored = try #require(TestImages.properties(ofFileAt: url))
        #expect(stored[kCGImagePropertyGPSDictionary] == nil)
    }

    // MARK: - load

    @Test func loadDownsamplesLegacyLargeFile() throws {
        let id = UUID()
        defer { ImageStorageService.delete(id: id) }
        try TestImages.writeRawStoredImage(TestImages.jpeg(width: 3000, height: 3000), id: id)

        let image = try #require(ImageStorageService.load(id: id))
        #expect(pixelSize(image) == CGSize(width: 1080, height: 1080))
    }

    @Test func loadRefusesLegacyHugeOrInvalidFile() throws {
        let bombID = UUID(), junkID = UUID()
        defer {
            ImageStorageService.delete(id: bombID)
            ImageStorageService.delete(id: junkID)
        }
        try TestImages.writeRawStoredImage(TestImages.compressionBombPNG(width: 8000, height: 8000), id: bombID)
        try TestImages.writeRawStoredImage(Data("not an image".utf8), id: junkID)

        #expect(ImageStorageService.load(id: bombID) == nil)
        #expect(ImageStorageService.load(id: junkID) == nil)
    }

    @Test func loadReturnsNilForMissingFile() {
        #expect(ImageStorageService.load(id: UUID()) == nil)
    }

    @Test func roundTripThroughSave() throws {
        let id = UUID()
        defer { ImageStorageService.delete(id: id) }
        let source = UIImage(cgImage: TestImages.cgImage(width: 500, height: 500))
        try ImageStorageService.save(image: source, id: id)
        #expect(ImageStorageService.load(id: id) != nil)
    }
}
