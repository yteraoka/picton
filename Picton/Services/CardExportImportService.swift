import Foundation
import SwiftData

enum CardExportImportService {

    // MARK: - Export Data Model

    struct ExportCard: Codable {
        let displayName: String
        let kanaText: String
        let category: String
        let hasImage: Bool
        /// Export 時の元 UUID（画像ファイル名と対応）
        let imageFileName: String?
    }

    struct ExportPayload: Codable {
        let version: Int
        let exportedAt: Date
        let cards: [ExportCard]
    }

    // MARK: - Errors

    enum ExportImportError: LocalizedError {
        case noCustomCards
        case invalidZip
        case invalidManifest
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .noCustomCards: return "エクスポートするカスタムカードがありません"
            case .invalidZip: return "ZIPファイルを読み込めませんでした"
            case .invalidManifest: return "カードデータが不正です"
            case .writeFailed: return "ファイルの書き込みに失敗しました"
            }
        }
    }

    // MARK: - Export

    /// カスタムカードを ZIP ファイルにエクスポートして tmp URL を返す
    static func exportCustomCards(_ cards: [PictureCard]) throws -> URL {
        let customCards = cards.filter { !$0.isPreset }
        guard !customCards.isEmpty else { throw ExportImportError.noCustomCards }

        // Build export payload
        let exportCards = customCards.map { card -> ExportCard in
            let hasImage = ImageStorageService.load(id: card.id) != nil
            return ExportCard(
                displayName: card.displayName,
                kanaText: card.kanaText,
                category: card.category,
                hasImage: hasImage,
                imageFileName: hasImage ? "\(card.id.uuidString).jpg" : nil
            )
        }

        let payload = ExportPayload(version: 1, exportedAt: Date(), cards: exportCards)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(payload)

        // Collect image files
        var imageEntries: [(name: String, data: Data)] = []
        for card in customCards {
            let fileURL = Constants.customImageDirectory
                .appendingPathComponent("\(card.id.uuidString).jpg")
            if let data = try? Data(contentsOf: fileURL) {
                imageEntries.append((name: "images/\(card.id.uuidString).jpg", data: data))
            }
        }

        // Build ZIP
        let zipData = buildZip(
            entries: [("cards.json", jsonData)] + imageEntries
        )

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PictonExport", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let zipURL = tmpDir.appendingPathComponent("picton_cards_export.zip")
        try zipData.write(to: zipURL)
        return zipURL
    }

    // MARK: - Import

    /// ZIP ファイルからカスタムカードをインポートし、追加したカード数を返す
    static func importCards(from zipURL: URL, context: ModelContext) throws -> Int {
        let accessing = zipURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { zipURL.stopAccessingSecurityScopedResource() }
        }

        let zipData = try Data(contentsOf: zipURL)
        let entries = try parseZip(data: zipData)

        guard let jsonEntry = entries.first(where: { $0.name == "cards.json" }) else {
            throw ExportImportError.invalidManifest
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayload.self, from: jsonEntry.data)

        guard payload.version == 1 else {
            throw ExportImportError.invalidManifest
        }

        // 既存カスタムカードの最大 sortOrder を取得
        let descriptor = FetchDescriptor<PictureCard>(
            sortBy: [SortDescriptor(\PictureCard.sortOrder, order: .reverse)]
        )
        let existing = try context.fetch(descriptor)
        var nextSortOrder = (existing.first?.sortOrder ?? -1) + 1

        // Build image lookup: original filename -> data
        var imageLookup: [String: Data] = [:]
        for entry in entries where entry.name.hasPrefix("images/") {
            let fileName = String(entry.name.dropFirst("images/".count))
            imageLookup[fileName] = entry.data
        }

        var importedCount = 0
        for exportCard in payload.cards {
            let newID = UUID()
            let card = PictureCard(
                id: newID,
                displayName: exportCard.displayName,
                kanaText: exportCard.kanaText,
                category: exportCard.category,
                isPreset: false,
                sortOrder: nextSortOrder,
                createdAt: Date()
            )
            context.insert(card)
            nextSortOrder += 1

            // 画像を新 UUID でコピー
            if exportCard.hasImage, let origFileName = exportCard.imageFileName,
               let imageData = imageLookup[origFileName] {
                let destDir = Constants.customImageDirectory
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                let destURL = destDir.appendingPathComponent("\(newID.uuidString).jpg")
                try imageData.write(to: destURL)
            }

            importedCount += 1
        }

        try context.save()
        return importedCount
    }

    // MARK: - ZIP Construction (store / no compression)

    private struct ZipEntry {
        let name: String
        let data: Data
    }

    /// 非圧縮 ZIP を構築
    private static func buildZip(entries: [(name: String, data: Data)]) -> Data {
        var localHeaders = Data()
        var centralDirectory = Data()
        var offsets: [UInt32] = []

        for (name, data) in entries {
            let nameData = Data(name.utf8)
            let crc = crc32(data)
            let offset = UInt32(localHeaders.count)
            offsets.append(offset)

            // Local file header
            var local = Data()
            local.appendUInt32(0x04034b50)  // signature
            local.appendUInt16(20)          // version needed
            local.appendUInt16(0)           // flags
            local.appendUInt16(0)           // compression: store
            local.appendUInt16(0)           // mod time
            local.appendUInt16(0)           // mod date
            local.appendUInt32(crc)         // crc-32
            local.appendUInt32(UInt32(data.count)) // compressed size
            local.appendUInt32(UInt32(data.count)) // uncompressed size
            local.appendUInt16(UInt16(nameData.count)) // name length
            local.appendUInt16(0)           // extra field length
            local.append(nameData)
            local.append(data)
            localHeaders.append(local)

            // Central directory entry
            var central = Data()
            central.appendUInt32(0x02014b50) // signature
            central.appendUInt16(20)         // version made by
            central.appendUInt16(20)         // version needed
            central.appendUInt16(0)          // flags
            central.appendUInt16(0)          // compression: store
            central.appendUInt16(0)          // mod time
            central.appendUInt16(0)          // mod date
            central.appendUInt32(crc)        // crc-32
            central.appendUInt32(UInt32(data.count)) // compressed size
            central.appendUInt32(UInt32(data.count)) // uncompressed size
            central.appendUInt16(UInt16(nameData.count)) // name length
            central.appendUInt16(0)          // extra field length
            central.appendUInt16(0)          // file comment length
            central.appendUInt16(0)          // disk number start
            central.appendUInt16(0)          // internal attrs
            central.appendUInt32(0)          // external attrs
            central.appendUInt32(offset)     // local header offset
            central.append(nameData)
            centralDirectory.append(central)
        }

        // End of central directory
        let cdOffset = UInt32(localHeaders.count)
        let cdSize = UInt32(centralDirectory.count)
        var eocd = Data()
        eocd.appendUInt32(0x06054b50)       // signature
        eocd.appendUInt16(0)                // disk number
        eocd.appendUInt16(0)                // central dir disk
        eocd.appendUInt16(UInt16(entries.count)) // entries on disk
        eocd.appendUInt16(UInt16(entries.count)) // total entries
        eocd.appendUInt32(cdSize)           // central dir size
        eocd.appendUInt32(cdOffset)         // central dir offset
        eocd.appendUInt16(0)                // comment length

        var result = Data()
        result.append(localHeaders)
        result.append(centralDirectory)
        result.append(eocd)
        return result
    }

    // MARK: - ZIP Parsing

    /// 非圧縮 ZIP をパースしてエントリ一覧を返す
    private static func parseZip(data: Data) throws -> [ZipEntry] {
        var entries: [ZipEntry] = []
        var offset = 0

        while offset + 4 <= data.count {
            let signature = data.readUInt32(at: offset)
            guard signature == 0x04034b50 else { break }

            let nameLength = Int(data.readUInt16(at: offset + 26))
            let extraLength = Int(data.readUInt16(at: offset + 28))
            let compressedSize = Int(data.readUInt32(at: offset + 18))

            let nameStart = offset + 30
            let nameEnd = nameStart + nameLength
            guard nameEnd <= data.count else { throw ExportImportError.invalidZip }
            let nameData = data[nameStart..<nameEnd]
            let name = String(data: nameData, encoding: .utf8) ?? ""

            let dataStart = nameEnd + extraLength
            let dataEnd = dataStart + compressedSize
            guard dataEnd <= data.count else { throw ExportImportError.invalidZip }
            let fileData = Data(data[dataStart..<dataEnd])

            entries.append(ZipEntry(name: name, data: fileData))
            offset = dataEnd
        }

        return entries
    }

    // MARK: - CRC-32

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Data helpers for little-endian writes/reads

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var v = value.littleEndian
        append(UnsafeBufferPointer(start: &v, count: 1))
    }

    mutating func appendUInt32(_ value: UInt32) {
        var v = value.littleEndian
        append(UnsafeBufferPointer(start: &v, count: 1))
    }

    func readUInt16(at offset: Int) -> UInt16 {
        subdata(in: offset..<offset + 2).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        subdata(in: offset..<offset + 4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    }
}
