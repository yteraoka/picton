import Foundation
import SwiftData
import Testing
@testable import Picton

@MainActor
@Suite("PresetImageBootstrapper")
struct PresetImageBootstrapperTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: PictureCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func fetchPresets() throws -> [PictureCard] {
        try context.fetch(FetchDescriptor<PictureCard>(
            predicate: #Predicate { $0.isPreset == true },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))
    }

    @Test func firstLaunchInsertsAllPresetsInOrder() throws {
        PresetImageBootstrapper.bootstrapIfNeeded(context: context)

        let presets = try fetchPresets()
        #expect(presets.map(\.presetImageName) == PresetCardData.all.map(\.sfSymbol))
        #expect(presets.map(\.presetID) == PresetCardData.all.map(\.id))
        #expect(presets.map(\.sortOrder) == Array(0..<PresetCardData.all.count))
    }

    @Test func secondLaunchIsIdempotent() throws {
        PresetImageBootstrapper.bootstrapIfNeeded(context: context)
        PresetImageBootstrapper.bootstrapIfNeeded(context: context)
        #expect(try fetchPresets().count == PresetCardData.all.count)
    }

    @Test func addsOnlyMissingPresetsAfterExistingSortOrder() throws {
        // 既存ユーザーの DB に先頭 2 件だけある状態（並べ替えで sortOrder が飛んでいる）
        let existing = Array(PresetCardData.all.prefix(2))
        for (definition, sortOrder) in zip(existing, [3, 10]) {
            context.insert(PictureCard(
                displayName: definition.displayName,
                kanaText: definition.kanaText,
                category: definition.category,
                isPreset: true,
                presetImageName: definition.sfSymbol,
                sortOrder: sortOrder
            ))
        }
        try context.save()

        PresetImageBootstrapper.bootstrapIfNeeded(context: context)

        let presets = try fetchPresets()
        #expect(presets.count == PresetCardData.all.count)
        // 既存カードの sortOrder は変えない
        #expect(presets.prefix(2).map(\.sortOrder) == [3, 10])
        // 新規分は既存の最大値の後ろに PresetCardData の順で並ぶ
        let added = presets.dropFirst(2)
        #expect(added.map(\.presetImageName) == PresetCardData.all.dropFirst(2).map(\.sfSymbol))
        #expect(added.map(\.sortOrder) == Array(11..<(11 + added.count)))
        // presetID を持たなかった既存 2 件にも ID が補完される
        #expect(presets.prefix(2).map(\.presetID) == existing.map(\.id))
    }

    @Test func removesDeletedPresetsButKeepsCustomCards() throws {
        PresetImageBootstrapper.bootstrapIfNeeded(context: context)
        context.insert(PictureCard(
            displayName: "渋谷", kanaText: "しぶや", category: "場所",
            isPreset: true, presetImageName: "preset_shibuya", sortOrder: 100
        ))
        // 同じ画像名でもカスタムカードは消さない
        context.insert(PictureCard(
            displayName: "マイ渋谷", kanaText: "しぶや", category: "場所",
            isPreset: false, presetImageName: "preset_shibuya", sortOrder: 101
        ))
        try context.save()

        PresetImageBootstrapper.bootstrapIfNeeded(context: context)

        let presets = try fetchPresets()
        #expect(!presets.contains { $0.presetImageName == "preset_shibuya" })
        #expect(presets.count == PresetCardData.all.count)
        let customs = try context.fetch(FetchDescriptor<PictureCard>(
            predicate: #Predicate { $0.isPreset == false }
        ))
        #expect(customs.map(\.displayName) == ["マイ渋谷"])
    }

    @Test func presetDefinitionsHaveUniqueIDs() {
        // presetID で既存判定するため、重複があると追加漏れになる
        let ids = PresetCardData.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    // MARK: - presetID の補完と ID ベースの同期 (#34)

    private func definition(_ id: String) throws -> PresetCardDefinition {
        try #require(PresetCardData.all.first { $0.id == id })
    }

    /// presetID 導入前の古いレコード（presetID なし）を挿入する
    @discardableResult
    private func insertLegacyPreset(
        _ displayName: String, category: String, symbol: String, sortOrder: Int, isHidden: Bool = false
    ) -> PictureCard {
        let card = PictureCard(
            displayName: displayName, kanaText: displayName, category: category,
            isPreset: true, presetImageName: symbol, sortOrder: sortOrder, isHidden: isHidden
        )
        context.insert(card)
        return card
    }

    /// 全定義について、古いレコードを用意した状態を作る
    private func insertAllLegacyPresets() {
        for (index, definition) in PresetCardData.all.enumerated() {
            insertLegacyPreset(definition.displayName, category: definition.category,
                               symbol: definition.sfSymbol, sortOrder: index)
        }
    }

    @Test func backfillsPresetIDsWithoutAddingDuplicates() throws {
        insertAllLegacyPresets()
        try context.save()

        PresetImageBootstrapper.bootstrapIfNeeded(context: context)

        let presets = try fetchPresets()
        #expect(presets.count == PresetCardData.all.count)
        #expect(presets.map(\.presetID) == PresetCardData.all.map(\.id))
    }

    /// 「歩き」を figure.walk で追加した旧バージョンの状態（「行きたい」とシンボルが重複）と、
    /// その後 figure.walk.motion に変えたバージョンで重複追加された「歩き」が混在していても、
    /// 「行きたい」と「歩き」が 1 枚ずつになる
    @Test func resolvesWalkSymbolCollisionAndDuplicate() throws {
        let walk = try definition("transport.walk")
        let wantToGo = try definition("action.want_to_go")
        for (index, definition) in PresetCardData.all.enumerated() where definition.id != walk.id {
            insertLegacyPreset(definition.displayName, category: definition.category,
                               symbol: definition.sfSymbol, sortOrder: index)
        }
        let oldWalk = insertLegacyPreset(walk.displayName, category: walk.category,
                                         symbol: "figure.walk", sortOrder: 100)
        insertLegacyPreset(walk.displayName, category: walk.category,
                           symbol: "figure.walk.motion", sortOrder: 101)
        try context.save()

        PresetImageBootstrapper.bootstrapIfNeeded(context: context)

        let presets = try fetchPresets()
        #expect(presets.count == PresetCardData.all.count)
        let walks = presets.filter { $0.presetID == walk.id }
        #expect(walks.count == 1)
        // sortOrder が小さい方が残り、シンボルは現在の定義に追従する
        #expect(walks.first?.id == oldWalk.id)
        #expect(walks.first?.presetImageName == walk.sfSymbol)
        let wantToGos = presets.filter { $0.presetID == wantToGo.id }
        #expect(wantToGos.count == 1)
        #expect(wantToGos.first?.presetImageName == "figure.walk")
    }

    /// 表示名を編集した古いプリセットはシンボルで照合され、編集内容は保たれる
    @Test func backfillsRenamedPresetBySymbol() throws {
        let park = try definition("place.park")
        insertAllLegacyPresets()
        try context.save()
        let renamed = try #require(try fetchPresets().first { $0.displayName == park.displayName })
        renamed.displayName = "いつもの公園"
        renamed.kanaText = "いつものこうえん"
        try context.save()

        PresetImageBootstrapper.bootstrapIfNeeded(context: context)

        let presets = try fetchPresets()
        #expect(presets.count == PresetCardData.all.count)
        #expect(renamed.presetID == park.id)
        #expect(renamed.displayName == "いつもの公園")
        #expect(renamed.kanaText == "いつものこうえん")
        #expect(!presets.contains { $0.displayName == park.displayName })
    }

    /// どの定義にも対応しない古いプリセットは消さずに残す
    @Test func keepsUnmatchedLegacyPresets() throws {
        insertAllLegacyPresets()
        insertLegacyPreset("ふしぎ", category: "生活", symbol: "questionmark", sortOrder: 200)
        try context.save()

        PresetImageBootstrapper.bootstrapIfNeeded(context: context)

        let presets = try fetchPresets()
        #expect(presets.count == PresetCardData.all.count + 1)
        let unmatched = try #require(presets.first { $0.displayName == "ふしぎ" })
        #expect(unmatched.presetID == nil)
    }

    /// 定義側でシンボルを変えると既存カードの画像が追従し、利用者の編集は上書きしない
    @Test func symbolChangeUpdatesExistingCardKeepingUserEdits() throws {
        let park = try definition("place.park")
        PresetImageBootstrapper.bootstrapIfNeeded(context: context)
        let card = try #require(try fetchPresets().first { $0.presetID == park.id })
        card.presetImageName = "old.symbol"
        card.displayName = "こうえん！"
        card.category = "生活"
        card.isHidden = true
        card.sortOrder = 99
        try context.save()

        PresetImageBootstrapper.bootstrapIfNeeded(context: context)

        let presets = try fetchPresets()
        #expect(presets.count == PresetCardData.all.count)
        #expect(card.presetImageName == park.sfSymbol)
        #expect(card.displayName == "こうえん！")
        #expect(card.category == "生活")
        #expect(card.isHidden)
        #expect(card.sortOrder == 99)
    }
}

// MARK: - スキーマの移行 (#61)

// プリセットの同期と同じく起動時のストアの扱いに関わるため、ここに置く
// （専用のテストファイルを追加するには xcodegen での再生成が必要）。
@MainActor
@Suite("SchemaMigration")
struct SchemaMigrationTests {
    private func makeStoreURL() throws -> (directory: URL, store: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("picton-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, directory.appendingPathComponent("test.store"))
    }

    /// バージョン管理を導入する前と同じ方法（ModelContainer(for:)）で作った V1 のストアを
    /// 移行計画付きで開くと、データを保ったまま V2 になり、重複した ID は 1 枚になる
    @Test func migratesUnversionedV1StoreAndRemovesDuplicateIDs() throws {
        let (directory, url) = try makeStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }

        let duplicatedID = UUID()
        let originID = UUID()
        do {
            let v1 = try ModelContainer(
                for: PictonSchemaV1.PictureCard.self,
                configurations: ModelConfiguration(url: url)
            )
            let context = v1.mainContext
            let keep = PictonSchemaV1.PictureCard(
                id: duplicatedID, displayName: "残す", kanaText: "のこす", category: "生活",
                originID: originID, sortOrder: 1, isHidden: true
            )
            keep.imageVersion = 3
            context.insert(keep)
            context.insert(PictonSchemaV1.PictureCard(
                id: duplicatedID, displayName: "重複", kanaText: "じゅうふく", category: "生活", sortOrder: 5
            ))
            context.insert(PictonSchemaV1.PictureCard(
                displayName: "公園", kanaText: "こうえん", category: "場所",
                isPreset: true, presetImageName: "tree.fill", presetID: "place.park", sortOrder: 0
            ))
            try context.save()
        }

        let v2 = try PictonModelContainer.make(url: url)
        let cards = try v2.mainContext.fetch(FetchDescriptor<PictureCard>(sortBy: [SortDescriptor(\.sortOrder)]))

        #expect(cards.map(\.displayName) == ["公園", "残す"])
        let kept = try #require(cards.last)
        #expect(kept.id == duplicatedID)
        #expect(kept.originID == originID)
        #expect(kept.isHidden)
        #expect(kept.imageVersion == 3)
        let preset = try #require(cards.first)
        #expect(preset.isPreset)
        #expect(preset.presetID == "place.park")
        #expect(preset.presetImageName == "tree.fill")
    }

    /// 一度 V2 で開いたストアは、もう一度開いても問題ない
    @Test func reopeningV2StoreKeepsData() throws {
        let (directory, url) = try makeStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            let container = try PictonModelContainer.make(url: url)
            container.mainContext.insert(PictureCard(displayName: "いぬ", kanaText: "いぬ", category: "生活"))
            try container.mainContext.save()
        }
        let reopened = try PictonModelContainer.make(url: url)
        #expect(try reopened.mainContext.fetchCount(FetchDescriptor<PictureCard>()) == 1)
    }

    @Test func latestSchemaIsCurrentModel() throws {
        let latest = try #require(PictonMigrationPlan.schemas.last)
        #expect(ObjectIdentifier(latest) == ObjectIdentifier(PictonSchemaV2.self))
        #expect(PictonMigrationPlan.stages.count == PictonMigrationPlan.schemas.count - 1)
    }
}
