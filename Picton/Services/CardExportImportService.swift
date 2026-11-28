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
        /// カードの出どころを表す ID。再インポート時の重複検出に使う。
        /// インポートしたカードは元のカードの ID を引き継ぐ（`PictureCard.originID ?? id`）。
        /// この項目がない古い ZIP も読めるよう Optional にしている
        var sourceID: UUID? = nil
    }

    struct ExportPayload: Codable {
        let version: Int
        let exportedAt: Date
        let cards: [ExportCard]
    }

    // MARK: - Errors

    enum ExportImportError: LocalizedError, Equatable {
        case noCustomCards
        case invalidZip
        /// 圧縮されている・データディスクリプタを使っているなど、本アプリが書き出さない形式の ZIP
        case unsupportedZipFormat
        case invalidManifest
        case writeFailed
        case fileTooLarge
        case tooManyEntries
        case manifestTooLarge
        case tooManyCards
        /// `index` は cards.json 内での 0 始まりの位置
        case invalidCard(index: Int, problem: CardProblem)

        var errorDescription: String? {
            switch self {
            case .noCustomCards: return "エクスポートするカスタムカードがありません"
            case .invalidZip: return "ZIPファイルを読み込めませんでした"
            case .unsupportedZipFormat:
                return "このZIP形式には対応していません。Picton でエクスポートしたZIPファイルを選択してください（Finder などで圧縮し直したZIPは読み込めません）"
            case .invalidManifest: return "カードデータが不正です"
            case .writeFailed: return "ファイルの書き込みに失敗しました"
            case .fileTooLarge:
                return "ファイルが大きすぎます（\(CardExportImportService.maxImportFileSize / 1024 / 1024) MB まで）"
            case .tooManyEntries: return "ZIPファイル内のファイルが多すぎます"
            case .manifestTooLarge: return "カードデータが大きすぎます"
            case .tooManyCards:
                return "カードが多すぎます（1 回に \(CardExportImportService.maxImportCardCount) 枚まで）"
            case let .invalidCard(index, problem):
                return "\(index + 1) 枚目のカード: \(problem.message)"
            }
        }
    }

    /// インポートするカードの内容の問題
    enum CardProblem: Equatable {
        case emptyDisplayName
        case displayNameTooLong
        case emptyKanaText
        case kanaTextTooLong
        case unknownCategory

        var message: String {
            switch self {
            case .emptyDisplayName: return "表示名が空です"
            case .displayNameTooLong:
                return "表示名が長すぎます（\(CardExportImportService.maxDisplayNameLength) 文字まで）"
            case .emptyKanaText: return "読みがなが空です"
            case .kanaTextTooLong:
                return "読みがなが長すぎます（\(CardExportImportService.maxKanaTextLength) 文字まで）"
            case .unknownCategory: return "カテゴリが不明です"
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
                imageFileName: hasImage ? "\(card.id.uuidString).jpg" : nil,
                sourceID: card.originID ?? card.id
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
            guard exportCards.contains(where: { $0.imageFileName == fileURL.lastPathComponent }) else { continue }
            do {
                let data = try Data(contentsOf: fileURL)
                imageEntries.append((name: "images/\(card.id.uuidString).jpg", data: data))
            } catch {
                // 画像なしとして書き出す（cards.json 側は画像ありのままなので、インポート時は画像なしになる）
                AppLog.transfer.error("Failed to read image for export \(card.id, privacy: .public): \(error)")
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

    // MARK: - Import limits

    /// インポートできる ZIP ファイルの最大サイズ
    static let maxImportFileSize = 50 * 1024 * 1024
    /// 1 回のインポートで追加できる最大カード数
    static let maxImportCardCount = 1_000
    /// ZIP 内の最大エントリ数（cards.json と、カード 1 枚につき画像 1 枚）
    static let maxZipEntryCount = maxImportCardCount + 1
    /// cards.json の最大サイズ
    ///
    /// 1 枚あたり 1KB 程度なので、上限の 1,000 枚でも十分に収まる。
    /// デコード前に弾くことで、件数チェックの前に巨大な配列を作らない。
    static let maxManifestSize = 2 * 1024 * 1024
    static let maxDisplayNameLength = 50
    static let maxKanaTextLength = 100

    // MARK: - Import

    struct ImportResult: Equatable {
        /// 追加したカード数
        let importedCount: Int
        /// 画像として読めない・大きすぎるため、画像なしで取り込んだカード数
        let skippedImageCount: Int
        /// 既に追加済みのためスキップしたカード数
        var skippedDuplicateCount: Int = 0
    }

    /// DB に追加する前の、検証・画像保存まで済んだカード
    struct PreparedCard: Sendable {
        let id: UUID
        let displayName: String
        let kanaText: String
        let category: String
        /// 元になったカードの ID（`PictureCard.originID` に保存する）
        let originID: UUID?
    }

    struct PreparedImport: Sendable {
        let cards: [PreparedCard]
        let skippedImageCount: Int
        /// 保存済みの画像（DB への追加に失敗したら消す）
        let savedImageIDs: [UUID]
        var skippedDuplicateCount: Int = 0
    }

    /// 重複判定に使う、既存のカスタムカードの情報
    struct ExistingCards: Sendable {
        /// 既存カードの ID と、インポートしたカードの元 ID
        var ids: Set<UUID> = []
        /// 出どころの ID を持たない古い ZIP のカード用に、内容で照合する
        var contents: Set<CardContent> = []

        init() {}

        @MainActor
        init(context: ModelContext) throws {
            let customs = try context.fetch(FetchDescriptor<PictureCard>(
                predicate: #Predicate { $0.isPreset == false }
            ))
            for card in customs {
                ids.insert(card.id)
                if let originID = card.originID { ids.insert(originID) }
                contents.insert(CardContent(card.displayName, card.kanaText, card.category))
            }
        }
    }

    struct CardContent: Hashable, Sendable {
        let displayName: String
        let kanaText: String
        let category: String

        init(_ displayName: String, _ kanaText: String, _ category: String) {
            self.displayName = displayName
            self.kanaText = kanaText
            self.category = category
        }
    }

    /// カードの出どころの ID。`sourceID` がない古い ZIP では画像ファイル名（`<元の UUID>.jpg`）から取り出す
    static func sourceID(of card: ExportCard) -> UUID? {
        if let sourceID = card.sourceID { return sourceID }
        guard let fileName = card.imageFileName, fileName.hasSuffix(".jpg") else { return nil }
        return UUID(uuidString: String(fileName.dropLast(".jpg".count)))
    }

    /// 既に追加済みのカードか
    ///
    /// 出どころの ID が分かるカードは ID だけで判定する（内容が同じでも別のカードとして扱う）。
    /// ID が分からない古い ZIP のカードは、表示名・読み・カテゴリがすべて同じなら追加済みとみなす。
    static func isDuplicate(_ card: ExportCard, of existing: ExistingCards) -> Bool {
        if let id = sourceID(of: card) {
            return existing.ids.contains(id)
        }
        return existing.contents.contains(CardContent(card.displayName, card.kanaText, card.category))
    }

    /// ZIP ファイルからカスタムカードをインポートする
    ///
    /// ファイルの読み込み・パース・画像の検証と保存はバックグラウンドで行い、
    /// DB への追加だけをメインスレッドで行う。
    /// - Parameter onProgress: 画像の処理が 1 枚進むごとに（処理済み枚数, 全枚数）で呼ばれる。
    ///   バックグラウンドスレッドから呼ばれる
    @MainActor
    static func importCards(
        from zipURL: URL,
        context: ModelContext,
        onProgress: @escaping @Sendable (_ completed: Int, _ total: Int) -> Void = { _, _ in }
    ) async throws -> ImportResult {
        let existing = try ExistingCards(context: context)
        let prepared = try await Task.detached(priority: .userInitiated) {
            try prepareImport(from: zipURL, existing: existing, onProgress: onProgress)
        }.value
        return try commit(prepared, context: context)
    }

    /// ZIP を読み込んで検証し、画像を新しい UUID で保存する（DB には触らない）
    ///
    /// ZIP は外部から来たデータなので、サイズ・件数・文字列をすべて検証してから画像を保存する。
    /// 不正なカードが 1 枚でもあれば何も保存せずにエラーにする。
    /// `existing` に既にあるカード（と、同じ ZIP 内で 2 回目以降に出てくるカード）はスキップする。
    static func prepareImport(
        from zipURL: URL,
        existing: ExistingCards = .init(),
        onProgress: (_ completed: Int, _ total: Int) -> Void = { _, _ in }
    ) throws -> PreparedImport {
        let accessing = zipURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { zipURL.stopAccessingSecurityScopedResource() }
        }

        let zipData = try readImportFile(at: zipURL)
        let entries = try parseZip(data: zipData)

        guard let jsonEntry = entries.first(where: { $0.name == "cards.json" }) else {
            throw ExportImportError.invalidManifest
        }
        guard jsonEntry.data.count <= maxManifestSize else {
            throw ExportImportError.manifestTooLarge
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayload.self, from: jsonEntry.data)

        guard payload.version == 1 else {
            throw ExportImportError.invalidManifest
        }

        let exportCards = try validatedCards(payload.cards)

        // Build image lookup: original filename -> data
        var imageLookup: [String: Data] = [:]
        for entry in entries where entry.name.hasPrefix("images/") {
            let fileName = String(entry.name.dropFirst("images/".count))
            imageLookup[fileName] = entry.data
        }

        var cards: [PreparedCard] = []
        var savedImageIDs: [UUID] = []
        var skippedImageCount = 0
        var skippedDuplicateCount = 0
        // 取り込むと決めたカードも加えていき、同じ ZIP 内の重複も弾く
        var known = existing
        do {
            for (index, exportCard) in exportCards.enumerated() {
                let originID = sourceID(of: exportCard)
                if isDuplicate(exportCard, of: known) {
                    skippedDuplicateCount += 1
                    onProgress(index + 1, exportCards.count)
                    continue
                }
                if let originID { known.ids.insert(originID) }
                known.contents.insert(CardContent(exportCard.displayName, exportCard.kanaText, exportCard.category))

                let newID = UUID()

                // 画像を新 UUID で保存する。ZIP の中身は外部から来たデータなので、
                // 画像として検証・縮小デコードしてから JPEG に再エンコードする（メタデータも除去される）。
                // 読めない・大きすぎる画像は、カード自体は取り込んで画像なしとして扱う
                if exportCard.hasImage, let origFileName = exportCard.imageFileName,
                   let imageData = imageLookup[origFileName] {
                    // 1 枚ごとにデコードした画像を解放し、メモリ使用量を一定に保つ
                    let saved = try autoreleasepool {
                        guard let image = ImageStorageService.sanitizedImage(from: imageData) else {
                            return false
                        }
                        _ = try ImageStorageService.save(image: image, id: newID)
                        return true
                    }
                    if saved {
                        savedImageIDs.append(newID)
                    } else {
                        skippedImageCount += 1
                    }
                }

                cards.append(PreparedCard(
                    id: newID,
                    displayName: exportCard.displayName,
                    kanaText: exportCard.kanaText,
                    category: exportCard.category,
                    originID: originID
                ))
                onProgress(index + 1, exportCards.count)
            }
        } catch {
            savedImageIDs.forEach(ImageStorageService.delete(id:))
            throw error
        }

        return PreparedImport(
            cards: cards,
            skippedImageCount: skippedImageCount,
            savedImageIDs: savedImageIDs,
            skippedDuplicateCount: skippedDuplicateCount
        )
    }

    /// 準備したカードを既存カードの後ろに追加する
    @MainActor
    static func commit(_ prepared: PreparedImport, context: ModelContext) throws -> ImportResult {
        do {
            var descriptor = FetchDescriptor<PictureCard>(
                sortBy: [SortDescriptor(\PictureCard.sortOrder, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            var nextSortOrder = (try context.fetch(descriptor).first?.sortOrder ?? -1) + 1

            for prepared in prepared.cards {
                context.insert(PictureCard(
                    id: prepared.id,
                    displayName: prepared.displayName,
                    kanaText: prepared.kanaText,
                    category: prepared.category,
                    isPreset: false,
                    originID: prepared.originID,
                    sortOrder: nextSortOrder,
                    createdAt: Date()
                ))
                nextSortOrder += 1
            }
            try context.save()
        } catch {
            context.rollback()
            prepared.savedImageIDs.forEach(ImageStorageService.delete(id:))
            throw error
        }
        return ImportResult(
            importedCount: prepared.cards.count,
            skippedImageCount: prepared.skippedImageCount,
            skippedDuplicateCount: prepared.skippedDuplicateCount
        )
    }

    /// インポートするファイルを上限サイズまで読み込む
    ///
    /// 先にファイルサイズで弾き、サイズが取れない場合や読み込み中に大きくなった場合も
    /// 上限 + 1 バイトまでしか読まないので、巨大なファイルを丸ごとメモリに載せない。
    static func readImportFile(at url: URL, maxSize: Int = maxImportFileSize) throws -> Data {
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxSize {
            throw ExportImportError.fileTooLarge
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maxSize + 1) ?? Data()
        guard data.count <= maxSize else { throw ExportImportError.fileTooLarge }
        return data
    }

    /// カードの件数と文字列を検証し、制御文字を除いてトリムしたものを返す
    static func validatedCards(_ cards: [ExportCard]) throws -> [ExportCard] {
        guard cards.count <= maxImportCardCount else { throw ExportImportError.tooManyCards }

        return try cards.enumerated().map { index, card in
            func fail(_ problem: CardProblem) -> ExportImportError {
                .invalidCard(index: index, problem: problem)
            }

            let displayName = sanitizedText(card.displayName)
            guard !displayName.isEmpty else { throw fail(.emptyDisplayName) }
            guard displayName.count <= maxDisplayNameLength else { throw fail(.displayNameTooLong) }

            let kanaText = sanitizedText(card.kanaText)
            guard !kanaText.isEmpty else { throw fail(.emptyKanaText) }
            guard kanaText.count <= maxKanaTextLength else { throw fail(.kanaTextTooLong) }

            // 一覧にないカテゴリのカードはどのタブにも表示されず、編集もできなくなる
            let category = sanitizedText(card.category)
            guard Constants.allCategories.contains(category) else { throw fail(.unknownCategory) }

            return ExportCard(
                displayName: displayName,
                kanaText: kanaText,
                category: category,
                hasImage: card.hasImage,
                imageFileName: card.imageFileName,
                sourceID: card.sourceID
            )
        }
    }

    /// 制御文字・改行・双方向テキストの制御文字を取り除き、前後の空白をトリムする
    ///
    /// 絵文字の結合に使うゼロ幅接合子（U+200D）などは残す。
    static func sanitizedText(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: text.unicodeScalars.filter { !isDisallowedScalar($0) })
        return String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isDisallowedScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .lineSeparator, .paragraphSeparator:
            return true
        default:
            switch scalar.value {
            case 0x200E, 0x200F, // LRM, RLM
                 0x202A...0x202E, // LRE, RLE, PDF, LRO, RLO
                 0x2066...0x2069: // LRI, RLI, FSI, PDI
                return true
            default:
                return false
            }
        }
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
    /// 本アプリが書き出す無圧縮（store）以外のエントリや、サイズを後ろのデータディスクリプタに置く
    /// エントリ（Finder などで作った ZIP）は `unsupportedZipFormat` を投げる (#39)。
    /// エントリが `maxEntryCount` を超えたら `tooManyEntries` を投げる。
    /// 各エントリの `data` は `data` を共有するスライス（コピーしない）。
    static func parseZip(data: Data, maxEntryCount: Int = maxZipEntryCount) throws -> [ZipEntry] {
        var entries: [ZipEntry] = []
        var offset = 0

        while let signature = data.readUInt32(at: offset), signature == 0x04034b50 {
            guard entries.count < maxEntryCount else { throw ExportImportError.tooManyEntries }
            guard offset + localFileHeaderSize <= data.count,
                  let flags = data.readUInt16(at: offset + 6),
                  let compressionMethod = data.readUInt16(at: offset + 8),
                  let crc = data.readUInt32(at: offset + 14),
                  let compressedSize = data.readUInt32(at: offset + 18),
                  let nameLength = data.readUInt16(at: offset + 26),
                  let extraLength = data.readUInt16(at: offset + 28)
            else { throw ExportImportError.invalidZip }

            // 圧縮方式 0（store）以外は展開できない。フラグの bit 3（データディスクリプタ）が立っていると
            // ローカルヘッダのサイズが 0 になっていて、エントリの終わりが分からない
            guard compressionMethod == 0, flags & 0x0008 == 0 else {
                throw ExportImportError.unsupportedZipFormat
            }

            let nameStart = offset + localFileHeaderSize
            let nameEnd = nameStart + Int(nameLength)
            let dataStart = nameEnd + Int(extraLength)
            let dataEnd = dataStart + Int(compressedSize)
            guard dataEnd <= data.count,
                  let nameData = data.slice(from: nameStart, to: nameEnd),
                  let fileData = data.slice(from: dataStart, to: dataEnd)
            else { throw ExportImportError.invalidZip }

            // 破損したファイルはここで弾かれる
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
    ///
    /// 元のバッファを共有するスライスを返す（インデックスは元の `Data` のまま）。
    func slice(from start: Int, to end: Int) -> Data? {
        guard start >= 0, start <= end, end <= count else { return nil }
        return self[(startIndex + start)..<(startIndex + end)]
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
