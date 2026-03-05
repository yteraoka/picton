import Foundation
import SwiftData
import SwiftUI

@Observable
final class CardLibraryViewModel {
    var selectedCategory: String = Constants.allCategories[0]

    func filteredCards(from allCards: [PictureCard]) -> [PictureCard] {
        return allCards
            .filter { !$0.isHidden && $0.category == selectedCategory }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}
