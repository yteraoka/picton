import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers
@testable import Picton

/// テスト用の画像データを作るヘルパー
enum TestImages {
    /// 指定ピクセル数（スケール 1）の画像
    static func cgImage(width: Int, height: Int) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        }
        return image.cgImage!
    }

    /// JPEG データ。`withGPS` なら EXIF に位置情報を埋め込む
    static func jpeg(width: Int, height: Int, withGPS: Bool = false) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.8]
        if withGPS {
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: 35.681,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 139.767,
                kCGImagePropertyGPSLongitudeRef: "E",
            ]
        }
        CGImageDestinationAddImage(destination, cgImage(width: width, height: height), properties as CFDictionary)
        precondition(CGImageDestinationFinalize(destination))
        return data as Data
    }

    /// 展開すると巨大になるが、ファイルは数 KB しかない有効な PNG（デコンプレッションボム）
    ///
    /// 全画素 0 の 1bit グレースケール画像は deflate で極端に小さくなる。
    /// 8000×8000（6,400 万ピクセル）で約 8KB、RGBA で展開すると約 256MB になる。
    static func compressionBombPNG(width: UInt32, height: UInt32) -> Data {
        func bigEndian(_ value: UInt32) -> [UInt8] { withUnsafeBytes(of: value.bigEndian, Array.init) }
        func chunk(_ type: String, _ body: Data) -> Data {
            let typeAndBody = Data(type.utf8) + body
            return Data(bigEndian(UInt32(body.count))) + typeAndBody
                + Data(bigEndian(CardExportImportService.crc32(typeAndBody)))
        }
        var ihdr = Data(bigEndian(width) + bigEndian(height))
        ihdr.append(contentsOf: [1, 0, 0, 0, 0]) // 1bit, グレースケール, deflate, filter 0, no interlace

        // 各行 = フィルタ種別 1 バイト + 画素データ。すべて 0
        let raw = Data(count: (Int(width + 7) / 8 + 1) * Int(height))
        let deflated = try! (raw as NSData).compressed(using: .zlib) as Data // zlib ヘッダなしの deflate
        let adler32 = (UInt32(raw.count % 65521) << 16) | 1 // 全バイト 0 の Adler-32
        let zlibStream = Data([0x78, 0x9C]) + deflated + Data(bigEndian(adler32))

        return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
            + chunk("IHDR", ihdr) + chunk("IDAT", zlibStream) + chunk("IEND", Data())
    }

    static func properties(of data: Data) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    }

    static func properties(ofFileAt url: URL) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    }

    static func storedImageURL(id: UUID) -> URL {
        Constants.customImageDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }

    /// 以前のバージョンが検証せずに保存したファイルを再現するため、生のバイト列を直接置く
    static func writeRawStoredImage(_ data: Data, id: UUID) throws {
        try FileManager.default.createDirectory(at: Constants.customImageDirectory, withIntermediateDirectories: true)
        try data.write(to: storedImageURL(id: id))
    }
}
