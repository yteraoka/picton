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
                        cardThumbnail(card)
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

    @ViewBuilder
    private func cardThumbnail(_ card: PictureCard) -> some View {
        if card.isPreset, let imageName = card.presetImageName, UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFill()
        } else if card.isPreset, let symbolName = card.presetImageName {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(categoryColor(for: card.category))
        } else if let uiImage = ImageStorageService.load(id: card.id) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.gray)
        }
    }
}
