import Foundation
import SwiftUI

@Observable
final class SentenceViewModel {
    private(set) var cards: [PictureCard] = []

    var isEmpty: Bool { cards.isEmpty }

    func append(_ card: PictureCard) {
        cards.append(card)
    }

    func remove(at index: Int) {
        guard cards.indices.contains(index) else { return }
        cards.remove(at: index)
    }

    func move(from source: Int, to destination: Int) {
        guard cards.indices.contains(source) else { return }
        let dest = min(max(destination, 0), cards.count)
        let card = cards.remove(at: source)
        cards.insert(card, at: dest > source ? dest - 1 : dest)
    }

    func clear() {
        cards.removeAll()
    }

    func fullKanaText() -> String {
        cards.map(\.kanaText).joined(separator: " ")
    }
}
