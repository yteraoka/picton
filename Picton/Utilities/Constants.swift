import Foundation
import SwiftUI

enum Constants {
    static let cardImageSize: CGFloat = 360
    static let cardImageCompressionQuality: CGFloat = 0.8

    static let gridItemMinSize: CGFloat = 100
    static let sentenceAreaHeight: CGFloat = 80

    static let ttsRate: Float = 0.42
    static let ttsPitchMultiplier: Float = 1.1
    static let ttsLanguage = "ja-JP"

    enum Colors {
        static let sentenceAreaBackground = Color(.systemGray6)
        static let cardBackground = Color.white
        static let cardBorder = Color(.systemGray4)
        static let categorySelected = Color.blue
        static let categoryDefault = Color(.systemGray5)
    }

    static var customImageDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("CustomCardImages", isDirectory: true)
    }

    static let allCategories = ["すべて", "場所", "動作", "気持ち", "食べ物", "人", "生活"]
}
