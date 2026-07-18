import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CardGridView: View {
    let cards: [PictureCard]
    let onCardTap: (PictureCard) -> Void
    let onCardLongPress: (PictureCard) -> Void
    let onAddTap: () -> Void
    var isEditMode: Bool = false
    var onReorder: ((PictureCard, PictureCard) -> Void)?

    @State private var draggedCard: PictureCard?
    // ドラッグが動き出してから元セルを隠す（リフトプレビューの
    // スナップショットが撮られる前に隠すとプレビューが真っ白になるため）
    @State private var isDragActive = false
    // provider の解放は最大2秒ほど遅れて届くことがあり、その間に次のドラッグ
    // セッションが始まっていると古い解放が新しい状態を消してしまう。
    // セッションごとのトークンで古い provider の後始末を無効化する
    @State private var dragToken = UUID()

    private let columns = [
        GridItem(.adaptive(minimum: Constants.gridItemMinSize), spacing: 10)
    ]

    var body: some View {
        ScrollView {
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
    }

    @ViewBuilder
    private func cardItem(for card: PictureCard) -> some View {
        let item = CardGridItemView(
            card: card,
            onTap: { onCardTap(card) },
            onLongPress: { onCardLongPress(card) },
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
                    let provider = DragSessionItemProvider(object: card.id.uuidString as NSString)
                    provider.didEnd = {
                        Task { @MainActor in
                            guard dragToken == token else { return }
                            draggedCard = nil
                            isDragActive = false
                        }
                    }
                    return provider
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

/// ドラッグセッションの終了（画面外ドロップやキャンセルを含む）を検知するための NSItemProvider
/// SwiftUI にはドラッグ終了のコールバックがないため、システムがセッション終了時に
/// provider を解放することを利用して後始末する
private final class DragSessionItemProvider: NSItemProvider {
    var didEnd: (() -> Void)?
    deinit { didEnd?() }
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
