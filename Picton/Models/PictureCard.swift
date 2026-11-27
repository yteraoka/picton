import Foundation
import SwiftData

/// 現在のモデル。アプリのコードはこの名前で参照する
typealias PictureCard = PictonSchemaV2.PictureCard

// MARK: - Schema versions
//
// モデルを変更するときは、現在のバージョンをそのまま残して新しいバージョンを追加し、
// `typealias PictureCard` を新しいバージョンに向け、`PictonMigrationPlan` にステージを足す。
// 既存のバージョンの定義は、リリース済みのストアを読むために必要なので変更しないこと (#61)。

/// V2: `id` に一意制約を追加
enum PictonSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [PictureCard.self] }

    @Model
    final class PictureCard: Identifiable {
        /// 一意制約は V2 で追加した。重複した ID は V1 → V2 の移行時に取り除く
        @Attribute(.unique) var id: UUID
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
        /// 画像を差し替えるたびに増やす番号。画像ファイル名（UUID）は変わらないため、
        /// 表示側はこの値の変化で画像を読み直す (#56)
        var imageVersion: Int = 0

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
}

/// V1: バージョン管理を導入する前のモデル（変更しないこと）
enum PictonSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [PictureCard.self] }

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
        /// 画像を差し替えるたびに増やす番号。画像ファイル名（UUID）は変わらないため、
        /// 表示側はこの値の変化で画像を読み直す (#56)
        var imageVersion: Int = 0

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
}

enum PictonMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PictonSchemaV1.self, PictonSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// 一意制約を付ける前に、同じ ID のカードを 1 枚にする（sortOrder が小さいものを残す）。
    /// 重複が残っていると移行に失敗してストアを開けなくなるため。
    static var migrateV1toV2: MigrationStage {
        .custom(
            fromVersion: PictonSchemaV1.self,
            toVersion: PictonSchemaV2.self,
            willMigrate: { context in
                let cards = try context.fetch(FetchDescriptor<PictonSchemaV1.PictureCard>(
                    sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
                ))
                var seen = Set<UUID>()
                for card in cards where !seen.insert(card.id).inserted {
                    context.delete(card)
                }
                try context.save()
            },
            didMigrate: nil
        )
    }
}

enum PictonModelContainer {
    /// 現在のスキーマと移行計画で ModelContainer を作る
    ///
    /// - Parameters:
    ///   - isStoredInMemoryOnly: UI テスト用にメモリ上のストアを使う
    ///   - url: ストアの場所（テスト用）。nil なら従来どおりの既定の場所
    static func make(isStoredInMemoryOnly: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PictonSchemaV2.self)
        if isStoredInMemoryOnly {
            return try ModelContainer(
                for: schema,
                migrationPlan: PictonMigrationPlan.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        if let url {
            return try ModelContainer(
                for: schema,
                migrationPlan: PictonMigrationPlan.self,
                configurations: ModelConfiguration(url: url)
            )
        }
        return try ModelContainer(for: schema, migrationPlan: PictonMigrationPlan.self)
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
    /// `PictureCard.imageVersion`。画像の差し替えを表示に反映するために使う
    let imageVersion: Int

    init(
        cardID: UUID?,
        displayName: String,
        kanaText: String,
        category: String,
        isPreset: Bool,
        presetImageName: String?,
        imageVersion: Int = 0
    ) {
        self.cardID = cardID
        self.displayName = displayName
        self.kanaText = kanaText
        self.category = category
        self.isPreset = isPreset
        self.presetImageName = presetImageName
        self.imageVersion = imageVersion
    }

    init(_ card: PictureCard) {
        self.init(
            cardID: card.id,
            displayName: card.displayName,
            kanaText: card.kanaText,
            category: card.category,
            isPreset: card.isPreset,
            presetImageName: card.presetImageName,
            imageVersion: card.imageVersion
        )
    }
}
