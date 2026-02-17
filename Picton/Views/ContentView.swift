import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PictureCard.sortOrder) private var allCards: [PictureCard]

    @State private var sentenceVM = SentenceViewModel()
    @State private var libraryVM = CardLibraryViewModel()
    @State private var ttsService = TTSService()

    @State private var showAddCard = false
    @State private var editingCard: PictureCard?

    var body: some View {
        VStack(spacing: 0) {
            SentenceAreaView(sentenceVM: sentenceVM, ttsService: ttsService)

            Divider()

            categoryFilter

            Divider()

            CardGridView(
                cards: libraryVM.filteredCards(from: allCards),
                onCardTap: { card in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sentenceVM.append(card)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                },
                onCardLongPress: { card in
                    editingCard = card
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                },
                onAddTap: {
                    showAddCard = true
                }
            )
        }
        .sheet(isPresented: $showAddCard) {
            AddCardView()
        }
        .sheet(item: $editingCard) { card in
            EditCardView(card: card)
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Constants.allCategories, id: \.self) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            libraryVM.selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(libraryVM.selectedCategory == category
                                          ? Constants.Colors.categorySelected
                                          : Constants.Colors.categoryDefault)
                            )
                            .foregroundStyle(libraryVM.selectedCategory == category ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(category)カテゴリ")
                    .accessibilityAddTraits(libraryVM.selectedCategory == category ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
