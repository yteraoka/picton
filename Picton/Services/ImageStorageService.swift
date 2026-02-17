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

        let fileURL = directory.appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: fileURL)
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
