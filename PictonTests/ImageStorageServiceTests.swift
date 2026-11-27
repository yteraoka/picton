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

    // MARK: - Aspect fill (#35)

    @Test(arguments: [
        // (画像の幅, 高さ, 期待する描画範囲 x, y, 幅, 高さ) を 360 四方に描く
        (400.0, 300.0, -60.0, 0.0, 480.0, 360.0), // 4:3 の横長（カメラ写真）
        (300.0, 400.0, 0.0, -60.0, 360.0, 480.0), // 3:4 の縦長
        (1000.0, 1000.0, 0.0, 0.0, 360.0, 360.0), // 正方形は縮小のみ
        (90.0, 45.0, -180.0, 0.0, 720.0, 360.0), // 小さい画像は拡大して埋める
    ])
    func aspectFillRect(
        width: Double, height: Double, x: Double, y: Double, rectWidth: Double, rectHeight: Double
    ) throws {
        let rect = try #require(ImageStorageService.aspectFillRect(
            for: CGSize(width: width, height: height), side: 360
        ))
        #expect(rect == CGRect(x: x, y: y, width: rectWidth, height: rectHeight))
    }

    @Test func aspectFillRectRejectsEmptySize() {
        #expect(ImageStorageService.aspectFillRect(for: .zero, side: 360) == nil)
        #expect(ImageStorageService.aspectFillRect(for: CGSize(width: 10, height: 0), side: 360) == nil)
    }

    @Test func saveRejectsEmptyImage() {
        let id = UUID()
        defer { ImageStorageService.delete(id: id) }
        #expect(throws: ImageStorageError.self) {
            try ImageStorageService.save(image: UIImage(), id: id)
        }
        #expect(!FileManager.default.fileExists(atPath: TestImages.storedImageURL(id: id).path))
    }

    /// 横長・縦長の画像は引き伸ばさず、中央を正方形に切り出して保存する
    ///
    /// 2:1 の画像の中央の正方形は緑の帯だけなので、四隅まで緑になる。
    /// 引き伸ばしていると端に赤・青の帯が残る。
    @Test(arguments: [(800, 400), (400, 800)])
    func saveCropsCenterSquareWithoutStretching(width: Int, height: Int) throws {
        let id = UUID()
        defer { ImageStorageService.delete(id: id) }
        _ = try ImageStorageService.save(image: TestImages.bandedImage(width: width, height: height), id: id)

        let url = TestImages.storedImageURL(id: id)
        let properties = try #require(TestImages.properties(ofFileAt: url))
        let storedWidth = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let storedHeight = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(storedWidth == storedHeight)

        for (x, y) in [(0.05, 0.05), (0.95, 0.05), (0.05, 0.95), (0.95, 0.95), (0.5, 0.5)] {
            #expect(
                TestImages.dominantChannel(atNormalized: CGPoint(x: x, y: y), ofFileAt: url) == .green,
                "(\(x), \(y)) が緑ではない"
            )
        }
    }

    // MARK: - 写真選択・カメラ画像の縮小 (#60)

    /// 選んだ写真は短辺が保存サイズ以上残るよう縮小デコードし、正方形に切り出しても拡大にならない
    @Test func pickedImageKeepsShortSideAtStoredSize() throws {
        let image = try #require(ImageStorageService.pickedImage(from: TestImages.jpeg(width: 3000, height: 1500)))
        let size = pixelSize(image)
        #expect(min(size.width, size.height) == CGFloat(ImageStorageService.storedPixelSize))
        #expect(abs(size.width / size.height - 2) < 0.01)
    }

    @Test func pickedImageDoesNotUpscaleSmallImage() throws {
        let image = try #require(ImageStorageService.pickedImage(from: TestImages.jpeg(width: 1200, height: 900)))
        #expect(pixelSize(image) == CGSize(width: 1200, height: 900))
    }

    @Test func pickedImageRejectsNonImageData() {
        #expect(ImageStorageService.pickedImage(from: Data("not an image".utf8)) == nil)
    }

    @Test func pickedPhotoLimitAllowsPanoramas() {
        // iPhone のパノラマ（約 16000×4000）は、インポート用の上限は超えるが写真選択では通す
        #expect(16_000 * 4_000 > ImageStorageService.maxSourcePixelCount)
        #expect(16_000 * 4_000 <= ImageStorageService.maxPickedPhotoPixelCount)
    }

    @Test func downscaledCameraImageKeepsShortSideAtStoredSize() {
        let source = UIImage(cgImage: TestImages.cgImage(width: 4000, height: 3000))
        let image = ImageStorageService.downscaled(source)
        #expect(pixelSize(image) == CGSize(width: 1440, height: 1080))
    }

    /// scale が 1 でない画像もピクセル数で判定する
    @Test func downscaledUsesPixelSizeOfScaledImage() {
        let cg = TestImages.cgImage(width: 2000, height: 1500)
        let source = UIImage(cgImage: cg, scale: 2, orientation: .up)  // 1000×750 pt
        let image = ImageStorageService.downscaled(source)
        #expect(pixelSize(image) == CGSize(width: 1440, height: 1080))
    }

    @Test func downscaledReturnsSmallImageAsIs() {
        let source = UIImage(cgImage: TestImages.cgImage(width: 800, height: 600))
        #expect(ImageStorageService.downscaled(source) === source)
    }

    /// 保存サイズは画面スケールによらず storedPixelSize 四方
    @Test func savedImageHasFixedPixelSize() throws {
        let id = UUID()
        defer { ImageStorageService.delete(id: id) }
        _ = try ImageStorageService.save(image: UIImage(cgImage: TestImages.cgImage(width: 2000, height: 1500)), id: id)

        let properties = try #require(TestImages.properties(ofFileAt: TestImages.storedImageURL(id: id)))
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == ImageStorageService.storedPixelSize)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == ImageStorageService.storedPixelSize)
    }

    @Test func roundTripThroughSave() throws {
        let id = UUID()
        defer { ImageStorageService.delete(id: id) }
        let source = UIImage(cgImage: TestImages.cgImage(width: 500, height: 500))
        try ImageStorageService.save(image: source, id: id)
        #expect(ImageStorageService.load(id: id) != nil)
    }
}
