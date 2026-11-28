import SwiftUI

/// 文エリアに並べた 1 枚のカード
///
/// タップするとそのカードを読み上げる。子どもが確かめようとして押しただけで
/// 消えてしまわないよう、削除は右上の × ボタンに分けている。
struct SentenceCardView: View {
    let card: CardSnapshot
    let onSpeak: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onSpeak) {
            VStack(spacing: 2) {
                CardImageView(card: card)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(card.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(4)
            .frame(width: 60, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(categoryColor(for: card.category).opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(categoryColor(for: card.category), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(card.displayName)を読み上げる")
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(.systemGray))
                    // 押しやすいよう、見た目より少し広く反応させる
                    .frame(width: 28, height: 28, alignment: .topTrailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: 2, y: -2)
            .accessibilityLabel("\(card.displayName)を削除")
        }
    }
}

func categoryColor(for category: String) -> Color {
    switch category {
    case "場所": return .blue
    case "動作": return .orange
    case "気持ち": return .pink
    case "食べ物": return .green
    case "人": return .purple
    case "生活": return .teal
    case "いつ": return .indigo
    case "手段": return .brown
    default: return .gray
    }
}
