import Foundation
import SwiftData

enum PresetImageBootstrapper {
    static func bootstrapIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<PictureCard>(
            predicate: #Predicate { $0.isPreset == true }
        )
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else { return }

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

        try? context.save()
    }
}
