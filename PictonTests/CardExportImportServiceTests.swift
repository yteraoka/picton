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
    @Test func importAddsCardsAfterExistingOnes() throws {
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

        let count = try Service.importCards(from: url, context: context)
        #expect(count == 2)

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

    @MainActor
    @Test func importRejectsTruncatedZip() throws {
        let container = try ModelContainer(
            for: PictureCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-truncated-\(UUID().uuidString).zip")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: Service.ExportImportError.self) {
            try Service.importCards(from: url, context: container.mainContext)
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PictureCard>()) == 0)
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
