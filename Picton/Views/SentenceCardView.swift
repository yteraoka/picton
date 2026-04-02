import SwiftUI

struct SentenceCardView: View {
    let card: PictureCard
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
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
        .accessibilityLabel("\(card.displayName)を削除")
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
    default: return .gray
    }
}
