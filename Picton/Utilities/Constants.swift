import Foundation
import os
import SwiftUI

enum Constants {
    static let cardImageSize: CGFloat = 360
    static let cardImageCompressionQuality: CGFloat = 0.8

    static let gridItemMinSize: CGFloat = 100
    static let sentenceAreaHeight: CGFloat = 80

    static let ttsRate: Float = 0.42
    static let ttsLanguage = "ja-JP"

    enum Colors {
        static let sentenceAreaBackground = Color(.systemGray6)
        static let cardBackground = Color(.secondarySystemGroupedBackground)
        static let cardBorder = Color(.systemGray4)
        static let categorySelected = Color.blue
        static let categoryDefault = Color(.systemGray5)
    }

    static var customImageDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("CustomCardImages", isDirectory: true)
    }

    /// UI テスト（起動引数 `--uitesting`）で起動されているか
    ///
    /// UI テストではインメモリストアを使い、読み上げ（音声合成・オーディオセッション）を無効にする。
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

    static let allCategories = ["いつ", "手段", "場所", "動作", "食べ物", "人", "生活", "気持ち"]
}

/// アプリ共通のロガー
///
/// 失敗を `try?` で黙って捨てず、最低限ここに残す (#38)。
enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "me.teraoka.Picton"
    /// SwiftData の読み書き
    static let data = Logger(subsystem: subsystem, category: "Data")
    /// カード画像の読み書き
    static let image = Logger(subsystem: subsystem, category: "Image")
    /// エクスポート・インポート
    static let transfer = Logger(subsystem: subsystem, category: "Transfer")
}
