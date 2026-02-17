import SwiftUI

struct CardGridItemView: View {
    let card: PictureCard
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 6) {
                cardImage
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
                    .stroke(categoryColor(for: card.category).opacity(0.3), lineWidth: 1)
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
        .accessibilityHint("タップして文に追加、長押しで編集")
    }

    @ViewBuilder
    private var cardImage: some View {
        if card.isPreset, let symbolName = card.presetImageName {
            Image(systemName: symbolName)
                .font(.title)
                .foregroundStyle(categoryColor(for: card.category))
        } else if let uiImage = ImageStorageService.load(id: card.id) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
                .font(.title)
                .foregroundStyle(.gray)
        }
    }
}
