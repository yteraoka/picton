import Foundation
import SwiftData

@Model
final class PictureCard: Identifiable {
    var id: UUID
    var displayName: String
    var kanaText: String
    var category: String
    var isPreset: Bool
    var presetImageName: String?
    var sortOrder: Int
    var createdAt: Date
    var isHidden: Bool = false

    init(
        id: UUID = UUID(),
        displayName: String,
        kanaText: String,
        category: String,
        isPreset: Bool = false,
        presetImageName: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        isHidden: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.kanaText = kanaText
        self.category = category
        self.isPreset = isPreset
        self.presetImageName = presetImageName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.isHidden = isHidden
    }
}
