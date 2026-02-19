import SwiftUI
import SwiftData

struct CardGridView: View {
    let cards: [PictureCard]
    let onCardTap: (PictureCard) -> Void
    let onCardLongPress: (PictureCard) -> Void
    let onAddTap: () -> Void
    var isReorderMode: Bool = false
    var onReorder: ((PictureCard, PictureCard) -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: Constants.gridItemMinSize), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(cards, id: \.id) { card in
                    cardItem(for: card)
                }

                if !isReorderMode {
                    addButton
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func cardItem(for card: PictureCard) -> some View {
        let item = CardGridItemView(
            card: card,
            onTap: { onCardTap(card) },
            onLongPress: { onCardLongPress(card) },
            isReorderMode: isReorderMode
        )

        if isReorderMode {
            item
                .draggable(card.id.uuidString)
                .dropDestination(for: String.self) { items, _ in
                    guard let draggedIDString = items.first,
                          let draggedID = UUID(uuidString: draggedIDString),
                          draggedID != card.id,
                          let draggedCard = cards.first(where: { $0.id == draggedID })
                    else { return false }
                    onReorder?(draggedCard, card)
                    return true
                }
        } else {
            item
        }
    }

    private var addButton: some View {
        Button(action: onAddTap) {
            VStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
                    .frame(width: 56, height: 56)

                Text("追加")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(Color.blue.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("カードを追加")
    }
}
