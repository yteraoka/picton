import Foundation
import SwiftData
import SwiftUI

@Observable
final class CardLibraryViewModel {
    var selectedCategory: String = "すべて"

    func filteredCards(from allCards: [PictureCard]) -> [PictureCard] {
        let visibleCards = allCards.filter { !$0.isHidden }
        if selectedCategory == "すべて" {
            return visibleCards.sorted { $0.sortOrder < $1.sortOrder }
        }
        return visibleCards
            .filter { $0.category == selectedCategory }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}
