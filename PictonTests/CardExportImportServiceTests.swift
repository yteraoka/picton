import Foundation
import SwiftData
import Testing
import UIKit
@testable import Picton

@Suite("CardExportImportService")
struct CardExportImportServiceTests {
    typealias Service = CardExportImportService

    private static let sampleEntries: [(name: String, data: Data)] = [
        ("cards.json", Data(#"{"a":1}"#.utf8)),
        ("images/x.jpg", Data((0..<5000).map { UInt8($0 & 0xFF) })),
    ]

    private func sampleZip() -> Data {
        Service.buildZip(entries: Self.sampleEntries)
    }

    private func isInvalidZip(_ data: Data) -> Bool {
        do {
            _ = try Service.parseZip(data: data)
            return false
        } catch Service.ExportImportError.invalidZip {
            return true
        } catch {
            return false
        }
    }

    // MARK: - Round trip

    @Test func buildAndParseRoundTrip() throws {
        let entries = try Service.parseZip(data: sampleZip())
        #expect(entries.map(\.name) == Self.sampleEntries.map(\.name))
        #expect(entries.map(\.data) == Self.sampleEntries.map(\.data))
    }

    @Test func emptyEntryRoundTrip() throws {
        let zip = Service.buildZip(entries: [("empty.txt", Data())])
        let entries = try Service.parseZip(data: zip)
        #expect(entries.count == 1)
        #expect(entries[0].data.isEmpty)
    }

    @Test func parsesSliceWithNonZeroStartIndex() throws {
        let padded = Data([1, 2, 3]) + sampleZip()
        let slice = padded[3...]
        #expect(slice.startIndex == 3)
        #expect(try Service.parseZip(data: slice).count == 2)
    }

    @Test func crc32KnownValue() {
        #expect(Service.crc32(Data("123456789".utf8)) == 0xCBF4_3926)
        #expect(Service.crc32(Data()) == 0)
    }

    // MARK: - Malformed input (#50)

    @Test func signatureOnlyIsInvalid() {
        #expect(isInvalidZip(Data([0x50, 0x4B, 0x03, 0x04])))
    }

    @Test func emptyDataHasNoEntries() throws {
        #expect(try Service.parseZip(data: Data()).isEmpty)
    }

    @Test func truncatedAtAnyOffsetDoesNotCrash() {
        let zip = sampleZip()
        for length in 0..<zip.count {
            // 例外になるか、途中までのエントリを返すかのどちらか。クラッシュしないこと
            _ = try? Service.parseZip(data: zip.prefix(length))
        }
        // ローカルヘッダの途中で切れたものは必ず invalidZip
        for length in 4..<30 {
            #expect(isInvalidZip(zip.prefix(length)), "length \(length)")
        }
    }

    @Test(arguments: [
        (offset: 18, bytes: [UInt8](repeating: 0xFF, count: 4)), // compressed size
        (offset: 26, bytes: [UInt8](repeating: 0xFF, count: 2)), // name length
        (offset: 28, bytes: [UInt8](repeating: 0xFF, count: 2)), // extra length
    ])
    func hugeLengthFieldIsInvalid(offset: Int, bytes: [UInt8]) {
        var zip = sampleZip()
        zip.replaceSubrange(offset..<offset + bytes.count, with: bytes)
        #expect(isInvalidZip(zip))
    }

    @Test func corruptedDataFailsCRC() {
        var zip = sampleZip()
        zip[40] ^= 0xFF // cards.json の本文
        #expect(isInvalidZip(zip))
    }

    @Test func randomMutationsDoNotCrash() {
        var rng = SeededGenerator(seed: 0x5EED)
        let zip = sampleZip()
        for _ in 0..<5_000 {
            var mutated = zip
            for _ in 0..<Int.random(in: 1...8, using: &rng) {
                mutated[Int.random(in: 0..<80, using: &rng)] = UInt8.random(in: 0...255, using: &rng)
            }
            if Bool.random(using: &rng) {
                mutated = mutated.prefix(Int.random(in: 0...mutated.count, using: &rng))
            }
            _ = try? Service.parseZip(data: mutated)
        }
    }

    // MARK: - Export file name (#53)

    @Test func exportFileNameContainsTimestamp() {
        var components = DateComponents()
        (components.year, components.month, components.day) = (2026, 11, 26)
        (components.hour, components.minute, components.second) = (9, 5, 7)
        let date = Calendar(identifier: .gregorian).date(from: components)!
        #expect(Service.exportFileName(date: date) == "picton_cards_20261126_090507.zip")
    }

    // MARK: - Import

    @MainActor
    @Test func importAddsCardsAfterExistingOnes() async throws {
        let container = try ModelContainer(
            for: PictureCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.insert(PictureCard(displayName: "既存", kanaText: "きそん", category: "人", sortOrder: 7))
        try context.save()

        let imageData = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
            .jpegData(withCompressionQuality: 0.8) { ctx in
                UIColor.red.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
        let payload = """
        {"version":1,"exportedAt":"2026-11-26T00:00:00Z","cards":[
          {"displayName":"いぬ","kanaText":"いぬ","category":"生活","hasImage":true,"imageFileName":"orig.jpg"},
          {"displayName":"ねこ","kanaText":"ねこ","category":"生活","hasImage":false}
        ]}
        """
        let zip = Service.buildZip(entries: [
            ("cards.json", Data(payload.utf8)),
            ("images/orig.jpg", imageData),
        ])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-test-\(UUID().uuidString).zip")
        try zip.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await Service.importCards(from: url, context: context)
        #expect(result == .init(importedCount: 2, skippedImageCount: 0))

        let imported = try context.fetch(FetchDescriptor<PictureCard>(
            predicate: #Predicate { $0.category == "生活" },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))
        defer { imported.forEach { ImageStorageService.delete(id: $0.id) } }

        #expect(imported.map(\.displayName) == ["いぬ", "ねこ"])
        #expect(imported.map(\.sortOrder) == [8, 9])
        #expect(imported.allSatisfy { !$0.isPreset })
        // 画像は新しい UUID で保存される
        #expect(ImageStorageService.load(id: imported[0].id) != nil)
        #expect(ImageStorageService.load(id: imported[1].id) == nil)
    }

    /// #52: ZIP 内の画像は検証・再エンコードしてから保存し、読めないものは画像なしで取り込む
    @MainActor
    @Test func importSanitizesImages() async throws {
        let container = try ModelContainer(
            for: PictureCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let payload = """
        {"version":1,"exportedAt":"2026-11-26T00:00:00Z","cards":[
          {"displayName":"写真","kanaText":"しゃしん","category":"生活","hasImage":true,"imageFileName":"photo.jpg"},
          {"displayName":"偽物","kanaText":"にせもの","category":"生活","hasImage":true,"imageFileName":"fake.jpg"},
          {"displayName":"巨大","kanaText":"きょだい","category":"生活","hasImage":true,"imageFileName":"bomb.jpg"}
        ]}
        """
        let zip = Service.buildZip(entries: [
            ("cards.json", Data(payload.utf8)),
            ("images/photo.jpg", TestImages.jpeg(width: 2000, height: 1000, withGPS: true)),
            ("images/fake.jpg", Data("this is not an image".utf8)),
            ("images/bomb.jpg", TestImages.compressionBombPNG(width: 8000, height: 8000)),
        ])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-sanitize-\(UUID().uuidString).zip")
        try zip.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await Service.importCards(from: url, context: context)
        #expect(result == .init(importedCount: 3, skippedImageCount: 2))

        let imported = try context.fetch(FetchDescriptor<PictureCard>(sortBy: [SortDescriptor(\.sortOrder)]))
        defer { imported.forEach { ImageStorageService.delete(id: $0.id) } }
        #expect(imported.map(\.displayName) == ["写真", "偽物", "巨大"])

        // 正常な画像は再エンコードされ、位置情報が除去され、カード用のサイズに縮小されている
        let stored = try #require(TestImages.properties(ofFileAt: TestImages.storedImageURL(id: imported[0].id)))
        #expect(stored[kCGImagePropertyGPSDictionary] == nil)
        let width = try #require(stored[kCGImagePropertyPixelWidth] as? Int)
        #expect(width <= ImageStorageService.maxDecodedPixelSize)

        // 画像として読めないもの・大きすぎるものはファイル自体を保存しない
        for card in imported.dropFirst() {
            #expect(!FileManager.default.fileExists(atPath: TestImages.storedImageURL(id: card.id).path))
            #expect(ImageStorageService.load(id: card.id) == nil)
        }
    }

    @MainActor
    @Test func importRejectsTruncatedZip() async throws {
        let container = try ModelContainer(
            for: PictureCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-truncated-\(UUID().uuidString).zip")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: Service.ExportImportError.self) {
            try await Service.importCards(from: url, context: container.mainContext)
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PictureCard>()) == 0)
    }

    // MARK: - Import limits (#51)

    private func card(
        _ displayName: String = "いぬ",
        kana: String = "いぬ",
        category: String = "生活"
    ) -> Service.ExportCard {
        .init(displayName: displayName, kanaText: kana, category: category, hasImage: false, imageFileName: nil)
    }

    private func writeTempZip(_ entries: [(name: String, data: Data)]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-limit-\(UUID().uuidString).zip")
        try Service.buildZip(entries: entries).write(to: url)
        return url
    }

    private func manifest(_ cards: [Service.ExportCard]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Service.ExportPayload(version: 1, exportedAt: Date(), cards: cards))
    }

    @Test func sanitizedTextRemovesControlCharacters() {
        #expect(Service.sanitizedText("  いぬ\n") == "いぬ")
        #expect(Service.sanitizedText("い\u{0}ぬ\u{7}\t") == "いぬ")
        #expect(Service.sanitizedText("い\u{2028}ぬ\u{2029}") == "いぬ")
        // 双方向テキストの制御文字（表示順を偽装できる）
        #expect(Service.sanitizedText("\u{202E}gnp.exe\u{202C}\u{200F}\u{2066}") == "gnp.exe")
        // 絵文字の結合（ZWJ）や異体字セレクタは残す
        #expect(Service.sanitizedText("👨‍👩‍👧") == "👨‍👩‍👧")
        #expect(Service.sanitizedText("☺️") == "☺️")
        #expect(Service.sanitizedText("おかあ さん") == "おかあ さん")
    }

    @Test func validatedCardsSanitizesText() throws {
        let cards = try Service.validatedCards([card(" い\u{0}ぬ\n", kana: "\tいぬ", category: " 生活 ")])
        #expect(cards.map(\.displayName) == ["いぬ"])
        #expect(cards.map(\.kanaText) == ["いぬ"])
        #expect(cards.map(\.category) == ["生活"])
    }

    @Test func validatedCardsAcceptsMaxLengths() throws {
        let name = String(repeating: "あ", count: Service.maxDisplayNameLength)
        let kana = String(repeating: "あ", count: Service.maxKanaTextLength)
        #expect(try Service.validatedCards([card(name, kana: kana)]).count == 1)
        // 文字数は見た目の 1 文字（書記素クラスタ）で数える
        let emoji = String(repeating: "👨‍👩‍👧", count: Service.maxDisplayNameLength)
        #expect(try Service.validatedCards([card(emoji)]).count == 1)
    }

    @Test(arguments: [
        (0, Service.CardProblem.emptyDisplayName),
        (1, .displayNameTooLong),
        (2, .emptyKanaText),
        (3, .kanaTextTooLong),
        (4, .unknownCategory),
        (5, .unknownCategory),
    ])
    func validatedCardsRejectsInvalidCard(index: Int, problem: Service.CardProblem) {
        let invalid = [
            card(" \n\u{0}"),
            card(String(repeating: "あ", count: Service.maxDisplayNameLength + 1)),
            card(kana: "\u{202E}"),
            card(kana: String(repeating: "あ", count: Service.maxKanaTextLength + 1)),
            card(category: "存在しない"),
            card(category: ""),
        ][index]
        // 何枚目のカードが不正かがエラーに含まれる
        #expect(throws: Service.ExportImportError.invalidCard(index: 1, problem: problem)) {
            try Service.validatedCards([card(), invalid, card()])
        }
    }

    @Test func validatedCardsLimitsCardCount() throws {
        let max = Array(repeating: card(), count: Service.maxImportCardCount)
        #expect(try Service.validatedCards(max).count == Service.maxImportCardCount)
        #expect(throws: Service.ExportImportError.tooManyCards) {
            try Service.validatedCards(max + [card()])
        }
    }

    @Test func parseZipLimitsEntryCount() throws {
        let entries = (0..<5).map { (name: "f\($0)", data: Data([UInt8($0)])) }
        #expect(try Service.parseZip(data: Service.buildZip(entries: entries), maxEntryCount: 5).count == 5)
        #expect(throws: Service.ExportImportError.tooManyEntries) {
            try Service.parseZip(data: Service.buildZip(entries: entries), maxEntryCount: 4)
        }
    }

    @Test func readImportFileLimitsSize() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-size-\(UUID().uuidString).zip")
        try Data(count: 100).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try Service.readImportFile(at: url, maxSize: 100).count == 100)
        #expect(throws: Service.ExportImportError.fileTooLarge) {
            try Service.readImportFile(at: url, maxSize: 99)
        }
    }

    @Test func importRejectsHugeManifest() throws {
        // 件数をデコードする前にサイズで弾く
        var json = try manifest([card()])
        json.append(Data(repeating: UInt8(ascii: " "), count: Service.maxManifestSize))
        let url = try writeTempZip([("cards.json", json)])
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: Service.ExportImportError.manifestTooLarge) {
            try Service.prepareImport(from: url)
        }
    }

    /// 不正なカードが 1 枚でもあれば、画像も含めて何も追加しない
    @MainActor
    @Test func importWithInvalidCardAddsNothing() async throws {
        let container = try ModelContainer(
            for: PictureCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let withImage = Service.ExportCard(
            displayName: "写真", kanaText: "しゃしん", category: "生活", hasImage: true, imageFileName: "a.jpg"
        )
        let url = try writeTempZip([
            ("cards.json", try manifest([withImage, card(category: "幽霊")])),
            ("images/a.jpg", TestImages.jpeg(width: 10, height: 10, withGPS: false)),
        ])
        defer { try? FileManager.default.removeItem(at: url) }
        let imagesBefore = storedImageFiles()

        await #expect(throws: Service.ExportImportError.invalidCard(index: 1, problem: .unknownCategory)) {
            try await Service.importCards(from: url, context: container.mainContext)
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PictureCard>()) == 0)
        #expect(storedImageFiles() == imagesBefore)
    }

    @MainActor
    @Test func importReportsProgress() async throws {
        let container = try ModelContainer(
            for: PictureCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let url = try writeTempZip([("cards.json", try manifest([card("いぬ"), card("ねこ"), card("とり")]))])
        defer { try? FileManager.default.removeItem(at: url) }

        let progress = ProgressRecorder()
        let result = try await Service.importCards(from: url, context: container.mainContext) { completed, total in
            progress.record(completed, total)
        }
        #expect(result == .init(importedCount: 3, skippedImageCount: 0))
        #expect(progress.values.map(\.completed) == [1, 2, 3])
        #expect(progress.values.allSatisfy { $0.total == 3 })
    }

    private func storedImageFiles() -> Set<String> {
        let files = try? FileManager.default.contentsOfDirectory(atPath: Constants.customImageDirectory.path)
        return Set(files ?? [])
    }
}

/// バックグラウンドから呼ばれる進捗コールバックの記録
private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [(completed: Int, total: Int)] = []

    func record(_ completed: Int, _ total: Int) {
        lock.lock()
        defer { lock.unlock() }
        recorded.append((completed, total))
    }

    var values: [(completed: Int, total: Int)] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }
}

/// 再現性のあるファジング用の乱数生成器（SplitMix64）
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
