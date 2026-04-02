import SwiftUI
import SwiftData

struct HiddenCardsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<PictureCard> { $0.isHidden },
           sort: \PictureCard.sortOrder) private var hiddenCards: [PictureCard]

    var body: some View {
        Group {
            if hiddenCards.isEmpty {
                ContentUnavailableView(
                    "非表示のカードはありません",
                    systemImage: "eye",
                    description: Text("非表示にしたカードがここに表示されます")
                )
            } else {
                List(hiddenCards) { card in
                    HStack(spacing: 12) {
                        CardImageView(card: card, symbolFont: .title3)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.displayName)
                                .font(.body)
                            Text(card.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("表示する") {
                            card.isHidden = false
                            try? modelContext.save()
                        }
                        .buttonStyle(.bordered)
                        .tint(.accentColor)
                    }
                }
            }
        }
        .navigationTitle("非表示カード")
        .navigationBarTitleDisplayMode(.inline)
    }

}
