import Foundation

struct PresetCardDefinition {
    /// プリセットを識別する安定した ID。
    ///
    /// DB の `PictureCard.presetID` に保存され、追加・削除・シンボル変更の判定に使う。
    /// **一度リリースした ID は変更・再利用しないこと。** 表示名やシンボルは自由に変えてよい。
    /// プリセットを廃止するときは `PresetImageBootstrapper.removedPresetIDs` に ID を追加する。
    let id: String
    let displayName: String
    let kanaText: String
    let category: String
    let sfSymbol: String
}

enum PresetCardData {
    static let all: [PresetCardDefinition] = places + actions + foods + people + daily + feelings + transportation

    // MARK: - 場所 (8)
    static let places: [PresetCardDefinition] = [
        PresetCardDefinition(id: "place.park", displayName: "公園", kanaText: "こうえん", category: "場所", sfSymbol: "tree.fill"),
        PresetCardDefinition(id: "place.hospital", displayName: "病院", kanaText: "びょういん", category: "場所", sfSymbol: "cross.case.fill"),
        PresetCardDefinition(id: "place.school", displayName: "学校", kanaText: "がっこう", category: "場所", sfSymbol: "building.columns.fill"),
        PresetCardDefinition(id: "place.home", displayName: "家", kanaText: "いえ", category: "場所", sfSymbol: "house.fill"),
        PresetCardDefinition(id: "place.shop", displayName: "お店", kanaText: "おみせ", category: "場所", sfSymbol: "cart.fill"),
        PresetCardDefinition(id: "place.hair_salon", displayName: "美容院", kanaText: "びよういん", category: "場所", sfSymbol: "scissors"),
        PresetCardDefinition(id: "place.toilet", displayName: "トイレ", kanaText: "トイレ", category: "場所", sfSymbol: "toilet.fill"),
        PresetCardDefinition(id: "place.pool", displayName: "プール", kanaText: "プール", category: "場所", sfSymbol: "figure.pool.swim"),
    ]

    // MARK: - 動作 (8)
    static let actions: [PresetCardDefinition] = [
        PresetCardDefinition(id: "action.want_to_go", displayName: "行きたい", kanaText: "いきたい", category: "動作", sfSymbol: "figure.walk"),
        PresetCardDefinition(id: "action.do", displayName: "します", kanaText: "します", category: "動作", sfSymbol: "hand.point.up.fill"),
        PresetCardDefinition(id: "action.want_to_eat", displayName: "食べたい", kanaText: "たべたい", category: "動作", sfSymbol: "fork.knife.circle.fill"),
        PresetCardDefinition(id: "action.want_to_drink", displayName: "飲みたい", kanaText: "のみたい", category: "動作", sfSymbol: "cup.and.saucer.fill"),
        PresetCardDefinition(id: "action.want_to_play", displayName: "遊びたい", kanaText: "あそびたい", category: "動作", sfSymbol: "gamecontroller.fill"),
        PresetCardDefinition(id: "action.want_to_see", displayName: "見たい", kanaText: "みたい", category: "動作", sfSymbol: "eye.fill"),
        PresetCardDefinition(id: "action.give_me", displayName: "ちょうだい", kanaText: "ちょうだい", category: "動作", sfSymbol: "hand.raised.fill"),
        PresetCardDefinition(id: "action.stop", displayName: "やめて", kanaText: "やめて", category: "動作", sfSymbol: "xmark.octagon.fill"),
    ]

    // MARK: - 気持ち (8)
    static let feelings: [PresetCardDefinition] = [
        PresetCardDefinition(id: "feeling.happy", displayName: "うれしい", kanaText: "うれしい", category: "気持ち", sfSymbol: "face.smiling.inverse"),
        PresetCardDefinition(id: "feeling.sad", displayName: "かなしい", kanaText: "かなしい", category: "気持ち", sfSymbol: "cloud.rain.fill"),
        PresetCardDefinition(id: "feeling.hurt", displayName: "いたい", kanaText: "いたい", category: "気持ち", sfSymbol: "bandage.fill"),
        PresetCardDefinition(id: "feeling.scared", displayName: "こわい", kanaText: "こわい", category: "気持ち", sfSymbol: "exclamationmark.triangle.fill"),
        PresetCardDefinition(id: "feeling.hungry", displayName: "おなかすいた", kanaText: "おなかすいた", category: "気持ち", sfSymbol: "mouth.fill"),
        PresetCardDefinition(id: "feeling.thirsty", displayName: "のどかわいた", kanaText: "のどかわいた", category: "気持ち", sfSymbol: "drop.fill"),
        PresetCardDefinition(id: "feeling.tired", displayName: "つかれた", kanaText: "つかれた", category: "気持ち", sfSymbol: "battery.25percent"),
        PresetCardDefinition(id: "feeling.fun", displayName: "たのしい", kanaText: "たのしい", category: "気持ち", sfSymbol: "star.fill"),
    ]

    // MARK: - 食べ物 (7)
    static let foods: [PresetCardDefinition] = [
        PresetCardDefinition(id: "food.meal", displayName: "ごはん", kanaText: "ごはん", category: "食べ物", sfSymbol: "takeoutbag.and.cup.and.straw.fill"),
        PresetCardDefinition(id: "food.bread", displayName: "パン", kanaText: "ぱん", category: "食べ物", sfSymbol: "birthday.cake.fill"),
        PresetCardDefinition(id: "food.onigiri", displayName: "おにぎり", kanaText: "おにぎり", category: "食べ物", sfSymbol: "triangle.fill"),
        PresetCardDefinition(id: "food.water", displayName: "お水", kanaText: "おみず", category: "食べ物", sfSymbol: "waterbottle.fill"),
        PresetCardDefinition(id: "food.juice", displayName: "ジュース", kanaText: "ジュース", category: "食べ物", sfSymbol: "mug.fill"),
        PresetCardDefinition(id: "food.snack", displayName: "おやつ", kanaText: "おやつ", category: "食べ物", sfSymbol: "gift.fill"),
        PresetCardDefinition(id: "food.fruit", displayName: "くだもの", kanaText: "くだもの", category: "食べ物", sfSymbol: "leaf.fill"),
    ]

    // MARK: - 人 (6)
    static let people: [PresetCardDefinition] = [
        PresetCardDefinition(id: "person.mother", displayName: "おかあさん", kanaText: "おかあさん", category: "人", sfSymbol: "person.crop.circle.fill"),
        PresetCardDefinition(id: "person.father", displayName: "おとうさん", kanaText: "おとうさん", category: "人", sfSymbol: "person.fill"),
        PresetCardDefinition(id: "person.teacher", displayName: "せんせい", kanaText: "せんせい", category: "人", sfSymbol: "graduationcap.fill"),
        PresetCardDefinition(id: "person.friend", displayName: "ともだち", kanaText: "ともだち", category: "人", sfSymbol: "person.2.fill"),
        PresetCardDefinition(id: "person.older_brother", displayName: "おにいちゃん", kanaText: "おにいちゃん", category: "人", sfSymbol: "figure.child"),
        PresetCardDefinition(id: "person.older_sister", displayName: "おねえちゃん", kanaText: "おねえちゃん", category: "人", sfSymbol: "person.crop.square.fill"),
    ]

    // MARK: - 生活 (8)
    static let daily: [PresetCardDefinition] = [
        PresetCardDefinition(id: "daily.good_morning", displayName: "おはよう", kanaText: "おはよう", category: "生活", sfSymbol: "sun.max.fill"),
        PresetCardDefinition(id: "daily.good_night", displayName: "おやすみ", kanaText: "おやすみ", category: "生活", sfSymbol: "moon.fill"),
        PresetCardDefinition(id: "daily.thank_you", displayName: "ありがとう", kanaText: "ありがとう", category: "生活", sfSymbol: "heart.fill"),
        PresetCardDefinition(id: "daily.sorry", displayName: "ごめんなさい", kanaText: "ごめんなさい", category: "生活", sfSymbol: "hand.wave.fill"),
        PresetCardDefinition(id: "daily.brush_teeth", displayName: "歯磨き", kanaText: "はみがき", category: "生活", sfSymbol: "sparkles"),
        PresetCardDefinition(id: "daily.bath", displayName: "お風呂", kanaText: "おふろ", category: "生活", sfSymbol: "bathtub.fill"),
        PresetCardDefinition(id: "daily.change_clothes", displayName: "着替え", kanaText: "きがえ", category: "生活", sfSymbol: "tshirt.fill"),
        PresetCardDefinition(id: "daily.wash_hands", displayName: "手洗い", kanaText: "てあらい", category: "生活", sfSymbol: "hands.and.sparkles.fill"),
    ]

    // MARK: - 手段 (5)
    static let transportation: [PresetCardDefinition] = [
        PresetCardDefinition(id: "transport.car", displayName: "くるま", kanaText: "くるまで", category: "手段", sfSymbol: "car.fill"),
        PresetCardDefinition(id: "transport.train", displayName: "電車", kanaText: "でんしゃで", category: "手段", sfSymbol: "tram.fill"),
        PresetCardDefinition(id: "transport.shinkansen", displayName: "新幹線", kanaText: "しんかんせんで", category: "手段", sfSymbol: "train.side.front.car"),
        PresetCardDefinition(id: "transport.airplane", displayName: "飛行機", kanaText: "ひこうきで", category: "手段", sfSymbol: "airplane"),
        PresetCardDefinition(id: "transport.walk", displayName: "歩き", kanaText: "あるいて", category: "手段", sfSymbol: "figure.walk.motion"),
    ]
}
