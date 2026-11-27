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

        // 前回のエクスポートが残っていれば消してから書き出す
        cleanUpExportDirectory()
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        // 受け取り側で上書きされないようファイル名に日時を含める
        let zipURL = exportDirectory.appendingPathComponent(exportFileName(date: payload.exportedAt))
        try zipData.write(to: zipURL, options: [.atomic, .completeFileProtection])
        return zipURL
    }

    /// エクスポート ZIP の一時置き場
    private static var exportDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PictonExport", isDirectory: true)
    }

    /// `picton_cards_20261126_153045.zip` 形式のファイル名
    static func exportFileName(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "picton_cards_\(formatter.string(from: date)).zip"
    }

    /// エクスポートした ZIP を削除する
    ///
    /// ZIP にはカスタムカードの写真一式が入るため、共有が終わったら tmp に残さない。
    static func removeExportedFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// エクスポート用の一時ディレクトリを丸ごと削除する（起動時・次回エクスポート前）
    static func cleanUpExportDirectory() {
        try? FileManager.default.removeItem(at: exportDirectory)
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
                try ImageStorageService.write(imageData: imageData, id: newID)
            }

            importedCount += 1
        }

        try context.save()
        return importedCount
    }

    // MARK: - ZIP Construction (store / no compression)

    struct ZipEntry {
        let name: String
        let data: Data
    }

    /// 非圧縮 ZIP を構築
    static func buildZip(entries: [(name: String, data: Data)]) -> Data {
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

    /// ローカルファイルヘッダの固定長部分のサイズ
    private static let localFileHeaderSize = 30

    /// 非圧縮 ZIP をパースしてエントリ一覧を返す
    ///
    /// 外部から受け取ったファイルを扱うため、すべての読み取りで範囲を検証し、
    /// 不正・破損した入力に対してはクラッシュせず `invalidZip` を投げる。
    static func parseZip(data: Data) throws -> [ZipEntry] {
        var entries: [ZipEntry] = []
        var offset = 0

        while let signature = data.readUInt32(at: offset), signature == 0x04034b50 {
            guard offset + localFileHeaderSize <= data.count,
                  let crc = data.readUInt32(at: offset + 14),
                  let compressedSize = data.readUInt32(at: offset + 18),
                  let nameLength = data.readUInt16(at: offset + 26),
                  let extraLength = data.readUInt16(at: offset + 28)
            else { throw ExportImportError.invalidZip }

            let nameStart = offset + localFileHeaderSize
            let nameEnd = nameStart + Int(nameLength)
            let dataStart = nameEnd + Int(extraLength)
            let dataEnd = dataStart + Int(compressedSize)
            guard dataEnd <= data.count,
                  let nameData = data.slice(from: nameStart, to: nameEnd),
                  let fileData = data.slice(from: dataStart, to: dataEnd)
            else { throw ExportImportError.invalidZip }

            // 破損ファイルや非対応の圧縮形式（deflate など）はここで弾かれる
            guard crc32(fileData) == crc else { throw ExportImportError.invalidZip }

            let name = String(data: nameData, encoding: .utf8) ?? ""
            entries.append(ZipEntry(name: name, data: fileData))
            offset = dataEnd
        }

        return entries
    }

    // MARK: - CRC-32

    private static let crc32Table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1 == 1) ? (c >> 1) ^ 0xEDB88320 : c >> 1
        }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crc32Table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Data helpers for little-endian writes/reads

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    /// 先頭からの相対オフセット `[from, to)` を切り出す。範囲外なら nil
    func slice(from start: Int, to end: Int) -> Data? {
        guard start >= 0, start <= end, end <= count else { return nil }
        return Data(self[(startIndex + start)..<(startIndex + end)])
    }

    /// 先頭からの相対オフセットにある little-endian の UInt16 を読む。範囲外なら nil
    func readUInt16(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else { return nil }
        let i = startIndex + offset
        return UInt16(self[i]) | UInt16(self[i + 1]) << 8
    }

    /// 先頭からの相対オフセットにある little-endian の UInt32 を読む。範囲外なら nil
    func readUInt32(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        let i = startIndex + offset
        return UInt32(self[i])
            | UInt32(self[i + 1]) << 8
            | UInt32(self[i + 2]) << 16
            | UInt32(self[i + 3]) << 24
    }
}
