import SwiftUI

struct CardGridItemView: View {
    let card: PictureCard
    let onTap: () -> Void
    let onLongPress: () -> Void
    var isEditMode: Bool = false

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 6) {
                CardImageView(card: card, symbolFont: .title)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(card.displayName)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(categoryColor(for: card.category).opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isEditMode
                            ? categoryColor(for: card.category)
                            : categoryColor(for: card.category).opacity(0.3),
                        lineWidth: isEditMode ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress()
                }
        )
        .accessibilityLabel(card.displayName)
        .accessibilityHint(isEditMode ? "タップで編集、ドラッグして並べ替え" : "タップして文に追加")
    }
}
