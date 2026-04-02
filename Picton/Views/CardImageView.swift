import SwiftUI

struct CardImageView: View {
    let card: PictureCard
    var symbolFont: Font = .title2

    @State private var customImage: UIImage?

    var body: some View {
        Group {
            if card.isPreset, let imageName = card.presetImageName, UIImage(named: imageName) != nil {
                Image(imageName)
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
        .task(id: card.id) {
            guard !card.isPreset else { return }
            customImage = await Task.detached { ImageStorageService.load(id: card.id) }.value
        }
    }
}
