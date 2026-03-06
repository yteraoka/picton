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
    @State private var dragOffset: CGFloat = 0
    @State private var viewWidth: CGFloat = 0
    @State private var isHorizontalDrag = false

    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            SentenceAreaView(sentenceVM: sentenceVM, ttsService: ttsService)

            Divider()

            categoryFilter

            Divider()

            GeometryReader { geometry in
                let width = geometry.size.width
                let categories = Constants.allCategories
                let currentIndex = categories.firstIndex(of: libraryVM.selectedCategory) ?? 0

                ZStack(alignment: .topLeading) {
                    // 前のカテゴリ（左側）
                    if currentIndex > 0 {
                        CardGridView(
                            cards: filteredCards(from: allCards, category: categories[currentIndex - 1]),
                            onCardTap: { _ in },
                            onCardLongPress: { _ in },
                            onAddTap: {},
                            isEditMode: false,
                            onReorder: nil
                        )
                        .frame(width: width)
                        .offset(x: dragOffset - width)
                    }

                    // 現在のカテゴリ
                    CardGridView(
                        cards: libraryVM.filteredCards(from: allCards),
                        onCardTap: { card in
                            guard !isHorizontalDrag else { return }
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
                            cards.insert(draggedCard, at: toIndex)
                            for (index, card) in cards.enumerated() {
                                card.sortOrder = index
                            }
                            try? modelContext.save()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    )
                    .frame(width: width)
                    .offset(x: dragOffset)

                    // 次のカテゴリ（右側）
                    if currentIndex < categories.count - 1 {
                        CardGridView(
                            cards: filteredCards(from: allCards, category: categories[currentIndex + 1]),
                            onCardTap: { _ in },
                            onCardLongPress: { _ in },
                            onAddTap: {},
                            isEditMode: false,
                            onReorder: nil
                        )
                        .frame(width: width)
                        .offset(x: dragOffset + width)
                    }
                }
                .scrollDisabled(isHorizontalDrag)
                .clipped()
                .onAppear { viewWidth = width }
                .onChange(of: geometry.size.width) { _, newWidth in viewWidth = newWidth }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            if !isHorizontalDrag {
                                // 方向が確定していない間は判定する
                                let isH = abs(value.translation.width) > abs(value.translation.height)
                                let isV = abs(value.translation.height) > abs(value.translation.width)
                                guard isH || isV else { return }
                                guard isH else { return } // 縦なら何もしない
                                isHorizontalDrag = true
                            }
                            let categories = Constants.allCategories
                            let idx = categories.firstIndex(of: libraryVM.selectedCategory) ?? 0
                            if value.translation.width > 0 && idx == 0 {
                                dragOffset = value.translation.width * 0.2
                            } else if value.translation.width < 0 && idx == categories.count - 1 {
                                dragOffset = value.translation.width * 0.2
                            } else {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            let wasHorizontal = isHorizontalDrag
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isHorizontalDrag = false
                            }
                            guard wasHorizontal else { return }
                            let threshold = width / 3
                            let categories = Constants.allCategories
                            guard let currentIndex = categories.firstIndex(of: libraryVM.selectedCategory) else { return }
                            if value.translation.width < -threshold, currentIndex < categories.count - 1 {
                                withAnimation(.spring(duration: 0.3)) { dragOffset = -width }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                                    libraryVM.selectedCategory = categories[currentIndex + 1]
                                    dragOffset = 0
                                }
                            } else if value.translation.width > threshold, currentIndex > 0 {
                                withAnimation(.spring(duration: 0.3)) { dragOffset = width }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                                    libraryVM.selectedCategory = categories[currentIndex - 1]
                                    dragOffset = 0
                                }
                            } else {
                                withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
                            }
                        },
                    including: isEditMode ? .none : .all
                )
            }
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

    private func switchCategory(to newCategory: String) {
        let categories = Constants.allCategories
        guard let newIndex = categories.firstIndex(of: newCategory),
              let currentIndex = categories.firstIndex(of: libraryVM.selectedCategory),
              newIndex != currentIndex else { return }
        let direction: CGFloat = newIndex > currentIndex ? -1 : 1
        withAnimation(.spring(duration: 0.3)) { dragOffset = direction * viewWidth }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            libraryVM.selectedCategory = newCategory
            dragOffset = 0
        }
    }

    private func filteredCards(from allCards: [PictureCard], category: String) -> [PictureCard] {
        allCards.filter { !$0.isHidden && $0.category == category }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Constants.allCategories, id: \.self) { category in
                    Button {
                        switchCategory(to: category)
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
