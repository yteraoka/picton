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
    /// プリセットの安定 ID（`PresetCardDefinition.id`）。カスタムカードは nil。
    /// 古いバージョンで作られたプリセットは起動時の移行処理で補完される。
    var presetID: String?
    /// インポートしたカードの、元になったカードの ID（エクスポート時の `sourceID`）。
    /// 同じカードを再インポートしたときに重複を検出するために使う。インポート以外で作ったカードは nil。
    var originID: UUID?
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
        presetID: String? = nil,
        originID: UUID? = nil,
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
        self.presetID = presetID
        self.originID = originID
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.isHidden = isHidden
    }
}

/// カードの表示・読み上げに必要な情報だけを持つ値型スナップショット。
///
/// 文エリアなど、SwiftData の `@Model` オブジェクトの寿命と切り離して
/// カードを保持したい場所で使う。`@Model` を直接保持すると、カード削除後に
/// 削除済みモデルのプロパティへアクセスしてしまうため。
struct CardSnapshot: Hashable {
    /// 元になった `PictureCard` の id。
    /// 「いつ」カテゴリの日付カードのように DB に存在しないカードは nil。
    let cardID: UUID?
    let displayName: String
    let kanaText: String
    let category: String
    let isPreset: Bool
    let presetImageName: String?

    init(
        cardID: UUID?,
        displayName: String,
        kanaText: String,
        category: String,
        isPreset: Bool,
        presetImageName: String?
    ) {
        self.cardID = cardID
        self.displayName = displayName
        self.kanaText = kanaText
        self.category = category
        self.isPreset = isPreset
        self.presetImageName = presetImageName
    }

    init(_ card: PictureCard) {
        self.init(
            cardID: card.id,
            displayName: card.displayName,
            kanaText: card.kanaText,
            category: card.category,
            isPreset: card.isPreset,
            presetImageName: card.presetImageName
        )
    }
}
