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
    @State private var isEditMode = false
    @State private var slideFromTrailing = true

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
                    if isEditMode {
                        editingCard = card
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sentenceVM.append(card)
                        }
                        ttsService.speak(card.kanaText)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                },
                onCardLongPress: { _ in },
                onAddTap: {
                    showAddCard = true
                },
                isEditMode: isEditMode,
                onReorder: { draggedCard, targetCard in
                    var cards = libraryVM.filteredCards(from: allCards)
                    guard let fromIndex = cards.firstIndex(where: { $0.id == draggedCard.id }),
                          let toIndex = cards.firstIndex(where: { $0.id == targetCard.id }),
                          fromIndex != toIndex
                    else { return }
                    cards.remove(at: fromIndex)
                    let insertAt = fromIndex < toIndex ? toIndex - 1 : toIndex
                    cards.insert(draggedCard, at: insertAt)
                    for (index, card) in cards.enumerated() {
                        card.sortOrder = index
                    }
                    try? modelContext.save()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            )
            .id(libraryVM.selectedCategory)
            .transition(.asymmetric(
                insertion: .move(edge: slideFromTrailing ? .trailing : .leading),
                removal: .move(edge: slideFromTrailing ? .leading : .trailing)
            ))
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 50, coordinateSpace: .local)
                    .onEnded { value in
                        // 水平方向の移動が縦方向より大きい場合のみカテゴリ切り替え
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let categories = Constants.allCategories
                        guard let currentIndex = categories.firstIndex(of: libraryVM.selectedCategory) else { return }
                        if value.translation.width < -50, currentIndex < categories.count - 1 {
                            slideFromTrailing = true
                            withAnimation(.easeInOut(duration: 0.25)) {
                                libraryVM.selectedCategory = categories[currentIndex + 1]
                            }
                        } else if value.translation.width > 50, currentIndex > 0 {
                            slideFromTrailing = false
                            withAnimation(.easeInOut(duration: 0.25)) {
                                libraryVM.selectedCategory = categories[currentIndex - 1]
                            }
                        }
                    }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditMode.toggle()
                    }
                } label: {
                    Text(isEditMode ? "完了" : "編集")
                        .fontWeight(isEditMode ? .semibold : .regular)
                }
                .accessibilityLabel(isEditMode ? "編集モード終了" : "編集モード")
            }
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
                        let categories = Constants.allCategories
                        if let newIndex = categories.firstIndex(of: category),
                           let currentIndex = categories.firstIndex(of: libraryVM.selectedCategory) {
                            slideFromTrailing = newIndex > currentIndex
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
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
