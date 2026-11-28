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

    /// 「元に戻す」で戻せる過去の状態（古い順）。
    /// 子どもが誤ってカードを消したり全部消したりしても戻せるようにする
    private(set) var history: [[SentenceItem]] = []

    /// 戻せる状態の最大数
    static let historyLimit = 50

    var isEmpty: Bool { items.isEmpty }

    /// 今と異なる状態に戻せるか
    var canUndo: Bool { history.contains { $0 != items } }

    func append(_ card: CardSnapshot) {
        recordHistory()
        items.append(SentenceItem(card: card))
    }

    func remove(id: SentenceItem.ID) {
        guard items.contains(where: { $0.id == id }) else { return }
        recordHistory()
        items.removeAll { $0.id == id }
    }

    /// 並べ替えを始める前に呼ぶ。ドラッグ中は `move` が何度も呼ばれるので、
    /// 並べ替え 1 回分をまとめて「元に戻す」で戻せるよう、開始時点の状態だけを記録する
    func beginReorder() {
        recordHistory()
    }

    func move(from source: Int, to destination: Int) {
        guard items.indices.contains(source) else { return }
        let dest = min(max(destination, 0), items.count)
        let item = items.remove(at: source)
        items.insert(item, at: dest > source ? dest - 1 : dest)
    }

    func clear() {
        guard !items.isEmpty else { return }
        recordHistory()
        items.removeAll()
    }

    /// 直前の操作を取り消す。今と同じ状態（中身の変わらなかった並べ替えなど）は読み飛ばす
    func undo() {
        while let previous = history.popLast() {
            if previous != items {
                items = previous
                return
            }
        }
    }

    func fullKanaText() -> String {
        items.map(\.card.kanaText).joined(separator: " ")
    }

    /// DB 上のカードの最新状態を文エリアに反映する。
    /// - 削除されたカードは文エリアから取り除く
    /// - 編集されたカードは表示名・読みなどを更新する
    /// - DB に存在しないカード（`cardID == nil` の日付カードなど）はそのまま残す
    ///
    /// 「元に戻す」で削除済みのカードが戻ってこないよう、過去の状態にも同じ反映を行う。
    func sync(with cards: [CardSnapshot]) {
        var latest: [UUID: CardSnapshot] = [:]
        for card in cards {
            if let id = card.cardID { latest[id] = card }
        }

        let synced = Self.synced(items, with: latest)
        if synced != items {
            items = synced
        }

        let syncedHistory = history.map { Self.synced($0, with: latest) }
        if syncedHistory != history {
            history = syncedHistory
        }
    }

    private static func synced(_ items: [SentenceItem], with latest: [UUID: CardSnapshot]) -> [SentenceItem] {
        items.compactMap { item -> SentenceItem? in
            guard let cardID = item.card.cardID else { return item }
            guard let updated = latest[cardID] else { return nil }
            var item = item
            item.card = updated
            return item
        }
    }

    private func recordHistory() {
        history.append(items)
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
    }
}
