import Foundation
import SwiftData
import SwiftUI

@Observable
final class CardLibraryViewModel {
    var selectedCategory: String = "すべて"

    func filteredCards(from allCards: [PictureCard]) -> [PictureCard] {
        if selectedCategory == "すべて" {
            return allCards.sorted { $0.sortOrder < $1.sortOrder }
        }
        return allCards
            .filter { $0.category == selectedCategory }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}
