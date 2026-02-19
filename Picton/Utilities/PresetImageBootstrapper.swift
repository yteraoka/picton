import Foundation
import SwiftData

enum PresetImageBootstrapper {
    /// 削除対象のプリセット画像名
    private static let removedPresetImageNames: Set<String> = [
        "preset_shibuya", "preset_kitasenju", "preset_mitsukoshimae",
        "preset_mcdonalds", "preset_saizeriya", "preset_gusto",
        "preset_ohsho", "preset_azamino",
        "preset_yakisoba", "preset_gyoza", "preset_pizza",
        "preset_ramen", "preset_ringo", "preset_udon",
        "preset_natto", "preset_kakipea", "preset_cola",
    ]

    static func bootstrapIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<PictureCard>(
            predicate: #Predicate { $0.isPreset == true }
        )
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        if existingCount == 0 {
            for (index, definition) in PresetCardData.all.enumerated() {
                let card = PictureCard(
                    displayName: definition.displayName,
                    kanaText: definition.kanaText,
                    category: definition.category,
                    isPreset: true,
                    presetImageName: definition.sfSymbol,
                    sortOrder: index
                )
                context.insert(card)
            }
        } else {
            removeDeletedPresets(context: context)
        }

        try? context.save()
    }

    /// PresetCardData から削除されたプリセットカードを DB からも除去する
    private static func removeDeletedPresets(context: ModelContext) {
        let descriptor = FetchDescriptor<PictureCard>(
            predicate: #Predicate { $0.isPreset == true }
        )
        guard let presets = try? context.fetch(descriptor) else { return }
        for card in presets {
            if let imageName = card.presetImageName,
               removedPresetImageNames.contains(imageName) {
                context.delete(card)
            }
        }
    }
}
