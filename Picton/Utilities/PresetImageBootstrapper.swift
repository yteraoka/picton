import Foundation
import SwiftData

/// 起動時にプリセットカードを DB と `PresetCardData` の定義に揃える。
///
/// プリセットの同一性は `PresetCardDefinition.id`（`PictureCard.presetID`）で判定する。
/// 以前は SF Symbol 名で判定していたため、シンボルを共有・変更すると追加漏れや重複が起きていた (#34)。
enum PresetImageBootstrapper {
    /// 廃止したプリセットの ID。DB に残っていれば削除する。
    /// `PresetCardData` から定義を消すときは、その ID をここに追加すること。
    static let removedPresetIDs: Set<String> = []

    /// presetID 導入前に廃止した画像プリセットの画像名（presetID を持たない古いレコード用）
    static let legacyRemovedPresetImageNames: Set<String> = [
        "preset_shibuya", "preset_kitasenju", "preset_mitsukoshimae",
        "preset_mcdonalds", "preset_saizeriya", "preset_gusto",
        "preset_ohsho", "preset_azamino",
        "preset_yakisoba", "preset_gyoza", "preset_pizza",
        "preset_ramen", "preset_ringo", "preset_udon",
        "preset_natto", "preset_kakipea", "preset_cola",
    ]

    static func bootstrapIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<PictureCard>(
            predicate: #Predicate { $0.isPreset == true },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        var presets: [PictureCard]
        do {
            presets = try context.fetch(descriptor)
        } catch {
            AppLog.data.error("Failed to fetch presets: \(error)")
            return
        }

        presets = removeLegacyDeletedPresets(presets, context: context)
        presets = assignMissingPresetIDs(presets, context: context)
        presets = removeDeletedPresets(presets, context: context)
        updateSymbols(presets)
        addMissingPresets(existing: presets, context: context)

        // 失敗しても既存のカードはそのまま使えるので、途中までの変更は捨てて次回の起動でやり直す
        context.saveOrRollback("bootstrap presets")
    }

    // MARK: - Steps

    /// presetID を持たない、廃止済みの画像プリセットを削除する
    private static func removeLegacyDeletedPresets(_ presets: [PictureCard], context: ModelContext) -> [PictureCard] {
        presets.filter { card in
            guard card.presetID == nil,
                  let imageName = card.presetImageName,
                  legacyRemovedPresetImageNames.contains(imageName) else { return true }
            context.delete(card)
            return false
        }
    }

    /// presetID を持たない古いレコードに、定義との照合で ID を補完する（一度きりの移行）。
    ///
    /// 1. 表示名 + カテゴリが一致する定義
    /// 2. 1 で決まらなかったものは、SF Symbol が一致する未使用の定義（表示名を編集していた場合）
    ///
    /// 同じ定義に複数のレコードが対応した場合（旧バージョンの不具合で重複していた場合）は、
    /// 既に ID を持つもの → sortOrder が小さいものを残し、残りを削除する。
    /// どの定義にも対応しないレコードは、利用者のデータを消さないよう、そのまま残す。
    private static func assignMissingPresetIDs(_ presets: [PictureCard], context: ModelContext) -> [PictureCard] {
        let unassigned = presets.filter { $0.presetID == nil }
        guard !unassigned.isEmpty else { return presets }

        var claimed = Set(presets.compactMap(\.presetID))
        var duplicates: [PictureCard] = []

        // 1. 表示名 + カテゴリで照合
        var stillUnassigned: [PictureCard] = []
        for card in unassigned {
            guard let definition = PresetCardData.all.first(where: {
                $0.displayName == card.displayName && $0.category == card.category
            }) else {
                stillUnassigned.append(card)
                continue
            }
            if claimed.contains(definition.id) {
                duplicates.append(card)
            } else {
                card.presetID = definition.id
                claimed.insert(definition.id)
            }
        }

        // 2. SF Symbol で照合（未使用の定義のみ）
        for card in stillUnassigned {
            guard let symbol = card.presetImageName,
                  let definition = PresetCardData.all.first(where: {
                      $0.sfSymbol == symbol && !claimed.contains($0.id)
                  }) else { continue }
            card.presetID = definition.id
            claimed.insert(definition.id)
        }

        for card in duplicates {
            context.delete(card)
        }
        let duplicateIDs = Set(duplicates.map(\.id))
        return presets.filter { !duplicateIDs.contains($0.id) }
    }

    /// 廃止したプリセットを削除する
    private static func removeDeletedPresets(_ presets: [PictureCard], context: ModelContext) -> [PictureCard] {
        presets.filter { card in
            guard let presetID = card.presetID, removedPresetIDs.contains(presetID) else { return true }
            context.delete(card)
            return false
        }
    }

    /// 定義側で SF Symbol を変更したプリセットの画像を追従させる。
    /// 表示名・読み・カテゴリは利用者が編集できるため上書きしない。
    private static func updateSymbols(_ presets: [PictureCard]) {
        let definitions = Dictionary(PresetCardData.all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for card in presets {
            guard let presetID = card.presetID, let definition = definitions[presetID] else { continue }
            if card.presetImageName != definition.sfSymbol {
                card.presetImageName = definition.sfSymbol
            }
        }
    }

    /// DB にまだないプリセットを、既存カードの後ろに `PresetCardData` の順で追加する
    private static func addMissingPresets(existing: [PictureCard], context: ModelContext) {
        let existingIDs = Set(existing.compactMap(\.presetID))
        let maxSortOrder = existing.map(\.sortOrder).max() ?? -1

        let missing = PresetCardData.all.filter { !existingIDs.contains($0.id) }
        for (offset, definition) in missing.enumerated() {
            context.insert(PictureCard(
                displayName: definition.displayName,
                kanaText: definition.kanaText,
                category: definition.category,
                isPreset: true,
                presetImageName: definition.sfSymbol,
                presetID: definition.id,
                sortOrder: maxSortOrder + 1 + offset
            ))
        }
    }
}
