import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CardGridView<Header: View>: View {
    let cards: [PictureCard]
    let onCardTap: (PictureCard) -> Void
    let onAddTap: () -> Void
    var isEditMode: Bool = false
    var onReorder: ((PictureCard, PictureCard) -> Void)?
    /// グリッドの上に表示し、グリッドと一緒にスクロールする内容（「いつ」カテゴリの日付カードなど）
    @ViewBuilder var header: () -> Header

    @State private var draggedCard: PictureCard?
    // ドラッグが動き出してから元セルを隠す（リフトプレビューの
    // スナップショットが撮られる前に隠すとプレビューが真っ白になるため）
    @State private var isDragActive = false
    // provider の解放は最大2秒ほど遅れて届くことがあり、その間に次のドラッグ
    // セッションが始まっていると古い解放が新しい状態を消してしまう。
    // セッションごとのトークンで古い provider の後始末を無効化する
    @State private var dragToken = UUID()
    // provider の解放（ドラッグ終了）の知らせを受け取る。どのスレッドで解放されるか決まっていないため、
    // View を直接捕捉せず、メインアクターのオブジェクト経由で受け取る (#62)
    @State private var dragEnd = DragEndSignal()

    private let columns = [
        GridItem(.adaptive(minimum: Constants.gridItemMinSize), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header()

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(cards, id: \.id) { card in
                        cardItem(for: card)
                    }

                    if isEditMode {
                        addButton
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .onDrop(of: [.text], delegate: CardDropCleanupDelegate(
            draggedCard: $draggedCard,
            isDragActive: $isDragActive
        ))
        .onChange(of: isEditMode) { _, newValue in
            if !newValue {
                draggedCard = nil
                isDragActive = false
            }
        }
        .onChange(of: dragEnd.endedToken) { _, endedToken in
            // 古いセッションの provider が遅れて解放された場合は無視する
            guard endedToken == dragToken else { return }
            draggedCard = nil
            isDragActive = false
        }
    }

    @ViewBuilder
    private func cardItem(for card: PictureCard) -> some View {
        let item = CardGridItemView(
            card: card,
            onTap: { onCardTap(card) },
            isEditMode: isEditMode
        )

        if isEditMode {
            item
                .opacity(draggedCard?.id == card.id && isDragActive ? 0 : 1)
                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12))
                .onDrag {
                    let token = UUID()
                    dragToken = token
                    draggedCard = card
                    // この provider へのドロップイベントはまだ届いていない
                    isDragActive = false
                    return DragSessionItemProvider(cardID: card.id) { [dragEnd] in
                        dragEnd.endedToken = token
                    }
                }
                .onDrop(of: [.text], delegate: CardReorderDropDelegate(
                    card: card,
                    draggedCard: $draggedCard,
                    isDragActive: $isDragActive,
                    onMove: { dragged, target in onReorder?(dragged, target) }
                ))
        } else {
            item
        }
    }

    private var addButton: some View {
        Button(action: onAddTap) {
            VStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)

                Text("追加")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(Color(.systemGray3))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("カードを追加")
    }
}

extension CardGridView where Header == EmptyView {
    init(
        cards: [PictureCard],
        onCardTap: @escaping (PictureCard) -> Void,
        onAddTap: @escaping () -> Void,
        isEditMode: Bool = false,
        onReorder: ((PictureCard, PictureCard) -> Void)? = nil
    ) {
        self.init(
            cards: cards,
            onCardTap: onCardTap,
            onAddTap: onAddTap,
            isEditMode: isEditMode,
            onReorder: onReorder,
            header: { EmptyView() }
        )
    }
}

/// ドラッグセッションの終了（画面外ドロップやキャンセルを含む）を検知するための NSItemProvider
/// SwiftUI にはドラッグ終了のコールバックがないため、システムがセッション終了時に
/// provider を解放することを利用して後始末する
///
/// 解放（deinit）はどのスレッドで起きるか決まっていないため、後始末はメインアクターで実行する (#62)。
private final class DragSessionItemProvider: NSItemProvider {
    private let onEnd: @MainActor @Sendable () -> Void

    init(cardID: UUID, onEnd: @escaping @MainActor @Sendable () -> Void) {
        self.onEnd = onEnd
        super.init()
        // NSItemProvider(object:) と同じく、カード ID を文字列として渡す
        registerObject(cardID.uuidString as NSString, visibility: .all)
    }

    deinit {
        let onEnd = onEnd
        Task { @MainActor in onEnd() }
    }
}

/// ドラッグセッションの終了の知らせ。最後に終了したセッションのトークンを持つ
@MainActor
@Observable
private final class DragEndSignal {
    var endedToken: UUID?
}

/// ドラッグ中にカードへ重なった時点でリアルタイムに並べ替える DropDelegate
private struct CardReorderDropDelegate: DropDelegate {
    let card: PictureCard
    @Binding var draggedCard: PictureCard?
    @Binding var isDragActive: Bool
    let onMove: (PictureCard, PictureCard) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedCard != nil
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedCard, dragged.id != card.id else { return }
        withAnimation(.spring(duration: 0.3)) {
            onMove(dragged, card)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if !isDragActive { isDragActive = true }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedCard = nil
        isDragActive = false
        return true
    }
}

/// カード以外の場所（グリッドの余白など）へのドロップで状態を後始末する DropDelegate
private struct CardDropCleanupDelegate: DropDelegate {
    @Binding var draggedCard: PictureCard?
    @Binding var isDragActive: Bool

    func validateDrop(info: DropInfo) -> Bool {
        draggedCard != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if !isDragActive { isDragActive = true }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedCard = nil
        isDragActive = false
        return true
    }
}
