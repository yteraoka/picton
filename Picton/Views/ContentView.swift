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
    @State private var showDataManagement = false

    var body: some View {
        NavigationStack {
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
                    ttsService.speak(card.kanaText)
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
            .gesture(
                DragGesture(minimumDistance: 50, coordinateSpace: .local)
                    .onEnded { value in
                        let categories = Constants.allCategories
                        guard let currentIndex = categories.firstIndex(of: libraryVM.selectedCategory) else { return }
                        if value.translation.width < -50, currentIndex < categories.count - 1 {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                libraryVM.selectedCategory = categories[currentIndex + 1]
                            }
                        } else if value.translation.width > 50, currentIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                libraryVM.selectedCategory = categories[currentIndex - 1]
                            }
                        }
                    }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDataManagement = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("データ管理")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showAddCard) {
            AddCardView()
        }
        .sheet(item: $editingCard) { card in
            EditCardView(card: card)
        }
        .sheet(isPresented: $showDataManagement) {
            DataManagementView()
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
