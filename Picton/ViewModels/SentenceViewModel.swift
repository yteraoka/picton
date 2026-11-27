import Foundation
import SwiftUI

/// 文エリアに並べた 1 枚分のカード。
///
/// 同じカードを複数回並べても区別できるよう、追加するたびに一意な `id` を振る。
struct SentenceItem: Identifiable, Hashable {
    let id: UUID
    var card: CardSnapshot

    init(id: UUID = UUID(), card: CardSnapshot) {
        self.id = id
        self.card = card
    }
}

@Observable
final class SentenceViewModel {
    private(set) var items: [SentenceItem] = []

    var isEmpty: Bool { items.isEmpty }

    func append(_ card: CardSnapshot) {
        items.append(SentenceItem(card: card))
    }

    func remove(id: SentenceItem.ID) {
        items.removeAll { $0.id == id }
    }

    func move(from source: Int, to destination: Int) {
        guard items.indices.contains(source) else { return }
        let dest = min(max(destination, 0), items.count)
        let item = items.remove(at: source)
        items.insert(item, at: dest > source ? dest - 1 : dest)
    }

    func clear() {
        items.removeAll()
    }

    func fullKanaText() -> String {
        items.map(\.card.kanaText).joined(separator: " ")
    }

    /// DB 上のカードの最新状態を文エリアに反映する。
    /// - 削除されたカードは文エリアから取り除く
    /// - 編集されたカードは表示名・読みなどを更新する
    /// - DB に存在しないカード（`cardID == nil` の日付カードなど）はそのまま残す
    func sync(with cards: [CardSnapshot]) {
        var latest: [UUID: CardSnapshot] = [:]
        for card in cards {
            if let id = card.cardID { latest[id] = card }
        }

        let synced = items.compactMap { item -> SentenceItem? in
            guard let cardID = item.card.cardID else { return item }
            guard let updated = latest[cardID] else { return nil }
            var item = item
            item.card = updated
            return item
        }

        if synced != items {
            items = synced
        }
    }
}
