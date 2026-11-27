import UIKit

enum ImageStorageService {
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
    @discardableResult
    static func write(imageData data: Data, id: UUID) throws -> URL {
        let directory = Constants.customImageDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        return fileURL
    }

    static func load(id: UUID) -> UIImage? {
        let fileURL = Constants.customImageDirectory.appendingPathComponent("\(id.uuidString).jpg")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
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
