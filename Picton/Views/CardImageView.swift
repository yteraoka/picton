import SwiftUI

struct CardImageView: View {
    let card: CardSnapshot
    var symbolFont: Font = .title2

    @State private var customImage: UIImage?

    init(card: CardSnapshot, symbolFont: Font = .title2) {
        self.card = card
        self.symbolFont = symbolFont
    }

    init(card: PictureCard, symbolFont: Font = .title2) {
        self.init(card: CardSnapshot(card), symbolFont: symbolFont)
    }

    var body: some View {
        Group {
            if card.isPreset, let imageName = card.presetImageName, let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if card.isPreset, let symbolName = card.presetImageName {
                Image(systemName: symbolName)
                    .font(symbolFont)
                    .foregroundStyle(categoryColor(for: card.category))
            } else if let uiImage = customImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(symbolFont)
                    .foregroundStyle(.gray)
            }
        }
        .task(id: card.cardID) {
            guard !card.isPreset, let id = card.cardID else { return }
            customImage = await Task.detached { ImageStorageService.load(id: id) }.value
        }
    }
}
