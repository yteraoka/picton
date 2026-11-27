import ImageIO
import UIKit

enum ImageStorageService {
    /// デコードを許可する元画像の最大ピクセル数（幅×高さ）
    ///
    /// ファイルサイズは小さくても展開すると数 GB になる画像（デコンプレッションボム）を
    /// デコード前に弾くための上限。iPhone の 48MP 写真（約 4,900 万ピクセル）は通す。
    static let maxSourcePixelCount = 50_000_000

    /// カード画像としてデコードするときの長辺の最大ピクセル数
    ///
    /// `save(image:id:)` は 360pt 四方を画面スケール（最大 3x）で描画するため、
    /// 保存される画像は最大 1080px 四方になる。それ以上で展開しても表示は変わらない。
    static let maxDecodedPixelSize = Int(Constants.cardImageSize) * 3

    static func save(image: UIImage, id: UUID) throws -> URL {
        let directory = Constants.customImageDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let size = CGSize(width: Constants.cardImageSize, height: Constants.cardImageSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        guard let data = resized.jpegData(compressionQuality: Constants.cardImageCompressionQuality) else {
            throw ImageStorageError.compressionFailed
        }

        return try write(imageData: data, id: id)
    }

    /// JPEG データをカード画像として保存する
    ///
    /// 子どもや家族の写真が入りやすいため、端末ロック中は読めない
    /// `.completeFileProtection` で書き込む（画像はアプリが前面にあるときしか使わない）。
    /// `.atomic` で途中終了時に壊れた JPEG が残らないようにする。
    /// 検証していないバイト列を書き込まないよう、`save(image:id:)` からのみ呼ぶ。
    @discardableResult
    private static func write(imageData data: Data, id: UUID) throws -> URL {
        let directory = Constants.customImageDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        return fileURL
    }

    /// 保存済みのカード画像を読み込む
    ///
    /// 以前のバージョンでインポートした未検証の画像が残っている可能性があるため、
    /// 読み込み時も縮小デコードし、大きすぎる画像は読まない。
    static func load(id: UUID) -> UIImage? {
        let fileURL = Constants.customImageDirectory.appendingPathComponent("\(id.uuidString).jpg")
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, sourceOptions),
              let cgImage = downsampledImage(from: source, maxPixelSize: maxDecodedPixelSize)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// 外部から受け取った画像データを検証し、カード画像として安全に扱える形にする
    ///
    /// 画像として読めないデータや、ピクセル数が `maxSourcePixelCount` を超えるものは nil。
    /// 縮小デコードした結果を返すので、`save(image:id:)` で JPEG に再エンコードすると
    /// EXIF（位置情報など）のメタデータも取り除かれる。
    static func sanitizedImage(
        from data: Data,
        maxSourcePixelCount: Int = ImageStorageService.maxSourcePixelCount
    ) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let cgImage = downsampledImage(
                from: source,
                maxPixelSize: maxDecodedPixelSize,
                maxSourcePixelCount: maxSourcePixelCount
              )
        else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// 元画像を丸ごと展開しないよう、ImageIO を直接使う
    private static let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary

    /// 画像のピクセル数を確認してから、長辺が `maxPixelSize` 以下になるよう縮小デコードする
    private static func downsampledImage(
        from source: CGImageSource,
        maxPixelSize: Int,
        maxSourcePixelCount: Int = ImageStorageService.maxSourcePixelCount
    ) -> CGImage? {
        guard CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, sourceOptions)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              // 幅・高さはそれぞれ高々 32bit なので、64bit の Int で掛けてもあふれない
              width * height <= maxSourcePixelCount
        else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // EXIF の向きを反映する
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
    }

    static func delete(id: UUID) {
        let fileURL = Constants.customImageDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// 既存の画像ファイルとディレクトリに `.complete` の保護クラスを適用する
    ///
    /// 以前のバージョンはデフォルトの保護クラス（`completeUntilFirstUserAuthentication`）で
    /// 保存していたため、起動時に未適用のものだけ付け直す。冪等なので毎回呼んでよい。
    static func applyCompleteFileProtection() {
        let fileManager = FileManager.default
        let directory = Constants.customImageDirectory
        guard fileManager.fileExists(atPath: directory.path) else { return }

        let files = (try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []
        for url in [directory] + files {
            let current = (try? fileManager.attributesOfItem(atPath: url.path))?[.protectionKey]
                as? FileProtectionType
            guard current != .complete else { continue }
            try? fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        }
    }
}

enum ImageStorageError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "画像の圧縮に失敗しました"
        }
    }
}
