import Foundation

struct PresetCardDefinition {
    let displayName: String
    let kanaText: String
    let category: String
    let sfSymbol: String
}

enum PresetCardData {
    static let all: [PresetCardDefinition] = places + actions + foods + people + daily + feelings

    // MARK: - 場所 (16)
    static let places: [PresetCardDefinition] = [
        PresetCardDefinition(displayName: "公園", kanaText: "こうえん", category: "場所", sfSymbol: "tree.fill"),
        PresetCardDefinition(displayName: "病院", kanaText: "びょういん", category: "場所", sfSymbol: "cross.case.fill"),
        PresetCardDefinition(displayName: "学校", kanaText: "がっこう", category: "場所", sfSymbol: "building.columns.fill"),
        PresetCardDefinition(displayName: "家", kanaText: "いえ", category: "場所", sfSymbol: "house.fill"),
        PresetCardDefinition(displayName: "お店", kanaText: "おみせ", category: "場所", sfSymbol: "cart.fill"),
        PresetCardDefinition(displayName: "美容院", kanaText: "びよういん", category: "場所", sfSymbol: "scissors"),
        PresetCardDefinition(displayName: "トイレ", kanaText: "トイレ", category: "場所", sfSymbol: "toilet.fill"),
        PresetCardDefinition(displayName: "プール", kanaText: "プール", category: "場所", sfSymbol: "figure.pool.swim"),
        PresetCardDefinition(displayName: "渋谷", kanaText: "しぶや", category: "場所", sfSymbol: "preset_shibuya"),
        PresetCardDefinition(displayName: "北千住", kanaText: "きたせんじゅ", category: "場所", sfSymbol: "preset_kitasenju"),
        PresetCardDefinition(displayName: "三越前", kanaText: "みつこしまえ", category: "場所", sfSymbol: "preset_mitsukoshimae"),
        PresetCardDefinition(displayName: "マクドナルド", kanaText: "マクドナルド", category: "場所", sfSymbol: "preset_mcdonalds"),
        PresetCardDefinition(displayName: "サイゼリヤ", kanaText: "サイゼリヤ", category: "場所", sfSymbol: "preset_saizeriya"),
        PresetCardDefinition(displayName: "ガスト", kanaText: "ガスト", category: "場所", sfSymbol: "preset_gusto"),
        PresetCardDefinition(displayName: "餃子の王将", kanaText: "ぎょうざのおうしょう", category: "場所", sfSymbol: "preset_ohsho"),
        PresetCardDefinition(displayName: "あざみ野", kanaText: "あざみの", category: "場所", sfSymbol: "preset_azamino"),
    ]

    // MARK: - 動作 (8)
    static let actions: [PresetCardDefinition] = [
        PresetCardDefinition(displayName: "行きたい", kanaText: "いきたい", category: "動作", sfSymbol: "figure.walk"),
        PresetCardDefinition(displayName: "します", kanaText: "します", category: "動作", sfSymbol: "hand.point.up.fill"),
        PresetCardDefinition(displayName: "食べたい", kanaText: "たべたい", category: "動作", sfSymbol: "fork.knife.circle.fill"),
        PresetCardDefinition(displayName: "飲みたい", kanaText: "のみたい", category: "動作", sfSymbol: "cup.and.saucer.fill"),
        PresetCardDefinition(displayName: "遊びたい", kanaText: "あそびたい", category: "動作", sfSymbol: "gamecontroller.fill"),
        PresetCardDefinition(displayName: "見たい", kanaText: "みたい", category: "動作", sfSymbol: "eye.fill"),
        PresetCardDefinition(displayName: "ちょうだい", kanaText: "ちょうだい", category: "動作", sfSymbol: "hand.raised.fill"),
        PresetCardDefinition(displayName: "やめて", kanaText: "やめて", category: "動作", sfSymbol: "xmark.octagon.fill"),
    ]

    // MARK: - 気持ち (8)
    static let feelings: [PresetCardDefinition] = [
        PresetCardDefinition(displayName: "うれしい", kanaText: "うれしい", category: "気持ち", sfSymbol: "face.smiling.inverse"),
        PresetCardDefinition(displayName: "かなしい", kanaText: "かなしい", category: "気持ち", sfSymbol: "cloud.rain.fill"),
        PresetCardDefinition(displayName: "いたい", kanaText: "いたい", category: "気持ち", sfSymbol: "bandage.fill"),
        PresetCardDefinition(displayName: "こわい", kanaText: "こわい", category: "気持ち", sfSymbol: "exclamationmark.triangle.fill"),
        PresetCardDefinition(displayName: "おなかすいた", kanaText: "おなかすいた", category: "気持ち", sfSymbol: "mouth.fill"),
        PresetCardDefinition(displayName: "のどかわいた", kanaText: "のどかわいた", category: "気持ち", sfSymbol: "drop.fill"),
        PresetCardDefinition(displayName: "つかれた", kanaText: "つかれた", category: "気持ち", sfSymbol: "battery.25percent"),
        PresetCardDefinition(displayName: "たのしい", kanaText: "たのしい", category: "気持ち", sfSymbol: "star.fill"),
    ]

    // MARK: - 食べ物 (16)
    static let foods: [PresetCardDefinition] = [
        PresetCardDefinition(displayName: "ごはん", kanaText: "ごはん", category: "食べ物", sfSymbol: "takeoutbag.and.cup.and.straw.fill"),
        PresetCardDefinition(displayName: "パン", kanaText: "ぱん", category: "食べ物", sfSymbol: "birthday.cake.fill"),
        PresetCardDefinition(displayName: "おにぎり", kanaText: "おにぎり", category: "食べ物", sfSymbol: "triangle.fill"),
        PresetCardDefinition(displayName: "お水", kanaText: "おみず", category: "食べ物", sfSymbol: "waterbottle.fill"),
        PresetCardDefinition(displayName: "ジュース", kanaText: "ジュース", category: "食べ物", sfSymbol: "mug.fill"),
        PresetCardDefinition(displayName: "おやつ", kanaText: "おやつ", category: "食べ物", sfSymbol: "gift.fill"),
        PresetCardDefinition(displayName: "くだもの", kanaText: "くだもの", category: "食べ物", sfSymbol: "leaf.fill"),
        PresetCardDefinition(displayName: "焼きそば", kanaText: "やきそば", category: "食べ物", sfSymbol: "preset_yakisoba"),
        PresetCardDefinition(displayName: "餃子", kanaText: "ぎょうざ", category: "食べ物", sfSymbol: "preset_gyoza"),
        PresetCardDefinition(displayName: "ピザ", kanaText: "ぴざ", category: "食べ物", sfSymbol: "preset_pizza"),
        PresetCardDefinition(displayName: "ラーメン", kanaText: "ラーメン", category: "食べ物", sfSymbol: "preset_ramen"),
        PresetCardDefinition(displayName: "りんご", kanaText: "りんご", category: "食べ物", sfSymbol: "preset_ringo"),
        PresetCardDefinition(displayName: "うどん", kanaText: "うどん", category: "食べ物", sfSymbol: "preset_udon"),
        PresetCardDefinition(displayName: "納豆", kanaText: "なっとう", category: "食べ物", sfSymbol: "preset_natto"),
        PresetCardDefinition(displayName: "柿ピー", kanaText: "かきぴー", category: "食べ物", sfSymbol: "preset_kakipea"),
        PresetCardDefinition(displayName: "コーラ", kanaText: "コーラ", category: "食べ物", sfSymbol: "preset_cola"),
    ]

    // MARK: - 人 (6)
    static let people: [PresetCardDefinition] = [
        PresetCardDefinition(displayName: "おかあさん", kanaText: "おかあさん", category: "人", sfSymbol: "person.crop.circle.fill"),
        PresetCardDefinition(displayName: "おとうさん", kanaText: "おとうさん", category: "人", sfSymbol: "person.fill"),
        PresetCardDefinition(displayName: "せんせい", kanaText: "せんせい", category: "人", sfSymbol: "graduationcap.fill"),
        PresetCardDefinition(displayName: "ともだち", kanaText: "ともだち", category: "人", sfSymbol: "person.2.fill"),
        PresetCardDefinition(displayName: "おにいちゃん", kanaText: "おにいちゃん", category: "人", sfSymbol: "figure.child"),
        PresetCardDefinition(displayName: "おねえちゃん", kanaText: "おねえちゃん", category: "人", sfSymbol: "person.crop.square.fill"),
    ]

    // MARK: - 生活 (8)
    static let daily: [PresetCardDefinition] = [
        PresetCardDefinition(displayName: "おはよう", kanaText: "おはよう", category: "生活", sfSymbol: "sun.max.fill"),
        PresetCardDefinition(displayName: "おやすみ", kanaText: "おやすみ", category: "生活", sfSymbol: "moon.fill"),
        PresetCardDefinition(displayName: "ありがとう", kanaText: "ありがとう", category: "生活", sfSymbol: "heart.fill"),
        PresetCardDefinition(displayName: "ごめんなさい", kanaText: "ごめんなさい", category: "生活", sfSymbol: "hand.wave.fill"),
        PresetCardDefinition(displayName: "歯磨き", kanaText: "はみがき", category: "生活", sfSymbol: "sparkles"),
        PresetCardDefinition(displayName: "お風呂", kanaText: "おふろ", category: "生活", sfSymbol: "bathtub.fill"),
        PresetCardDefinition(displayName: "着替え", kanaText: "きがえ", category: "生活", sfSymbol: "tshirt.fill"),
        PresetCardDefinition(displayName: "手洗い", kanaText: "てあらい", category: "生活", sfSymbol: "hands.and.sparkles.fill"),
    ]
}
