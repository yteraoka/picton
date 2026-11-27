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

    @Test func presetDefinitionsHaveUniqueSymbols() {
        // addNewPresets は sfSymbol で既存判定するため、重複があると追加漏れになる
        let symbols = PresetCardData.all.map(\.sfSymbol)
        #expect(Set(symbols).count == symbols.count)
    }
}
