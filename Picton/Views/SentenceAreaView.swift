import SwiftUI

struct SentenceAreaView: View {
    var sentenceVM: SentenceViewModel
    let ttsService: TTSService

    // 並べ替えはカードグリッドと同じく、ドラッグ中に重なった時点でリアルタイムに入れ替える (#45)。
    // 状態の扱いは CardGridView と同じ（理由は CardGridView のコメントを参照）
    @State private var draggedItemID: SentenceItem.ID?
    @State private var isDragActive = false
    @State private var dragToken = UUID()
    @State private var dragEnd = DragEndSignal()

    var body: some View {
        HStack(spacing: 8) {
            PlaybackButtonView(
                isSpeaking: ttsService.isSpeaking,
                onTap: {
                    if ttsService.isSpeaking {
                        ttsService.stop()
                    } else {
                        let text = sentenceVM.fullKanaText()
                        ttsService.speak(text)
                    }
                }
            )
            .disabled(sentenceVM.isEmpty)
            .opacity(sentenceVM.isEmpty ? 0.4 : 1.0)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(sentenceVM.items) { item in
                            sentenceCard(for: item)
                                .id(item.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                // カードを足したら、末尾（足したカード）が見えるようにスクロールする
                .onChange(of: sentenceVM.items.last?.id) { _, lastID in
                    guard let lastID, draggedItemID == nil else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .trailing)
                    }
                }
            }
            // カード以外の場所（余白など）へのドロップでも状態を後始末する
            .onDrop(of: [.text], delegate: SentenceDropCleanupDelegate(
                draggedItemID: $draggedItemID,
                isDragActive: $isDragActive
            ))
            .onChange(of: dragEnd.endedToken) { _, endedToken in
                // 古いセッションの provider が遅れて解放された場合は無視する
                guard endedToken == dragToken else { return }
                draggedItemID = nil
                isDragActive = false
            }

            // 「元に戻す」と「すべて消す」は常に同じ位置に置き、使えないときは薄くする
            // （出たり消えたりすると文エリアの幅が変わり、カードの位置がずれるため）
            VStack(spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sentenceVM.undo()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.title3)
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                }
                .disabled(!sentenceVM.canUndo)
                .opacity(sentenceVM.canUndo ? 1 : 0.3)
                .accessibilityLabel("元に戻す")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sentenceVM.clear()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                }
                .disabled(sentenceVM.isEmpty)
                .opacity(sentenceVM.isEmpty ? 0.3 : 1)
                .accessibilityLabel("すべて消す")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: Constants.sentenceAreaHeight)
        .background(Constants.Colors.sentenceAreaBackground)
    }

    private func sentenceCard(for item: SentenceItem) -> some View {
        SentenceCardView(
            card: item.card,
            onSpeak: { ttsService.speak(item.card.kanaText) },
            onRemove: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sentenceVM.remove(id: item.id)
                }
            }
        )
        // ドラッグが動き出してから元のカードを隠す（リフトプレビューが撮られる前に隠すと真っ白になる）
        .opacity(draggedItemID == item.id && isDragActive ? 0 : 1)
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 8))
        .onDrag {
            let token = UUID()
            dragToken = token
            draggedItemID = item.id
            isDragActive = false
            // 並べ替え 1 回分を「元に戻す」で戻せるようにする
            sentenceVM.beginReorder()
            return DragSessionItemProvider(id: item.id) { [dragEnd] in
                dragEnd.endedToken = token
            }
        }
        .onDrop(of: [.text], delegate: SentenceReorderDropDelegate(
            targetID: item.id,
            draggedItemID: $draggedItemID,
            isDragActive: $isDragActive,
            onMove: { draggedID, targetID in
                guard let from = sentenceVM.items.firstIndex(where: { $0.id == draggedID }),
                      let to = sentenceVM.items.firstIndex(where: { $0.id == targetID }),
                      from != to else { return }
                // move(from:to:) の移動先は「移動前の配列での挿入位置」なので、右へ動かすときは 1 つ後ろ
                sentenceVM.move(from: from, to: to > from ? to + 1 : to)
            }
        ))
    }
}

/// ドラッグ中に文のカードへ重なった時点でリアルタイムに並べ替える DropDelegate
private struct SentenceReorderDropDelegate: DropDelegate {
    let targetID: SentenceItem.ID
    @Binding var draggedItemID: SentenceItem.ID?
    @Binding var isDragActive: Bool
    let onMove: (SentenceItem.ID, SentenceItem.ID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedItemID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItemID, dragged != targetID else { return }
        withAnimation(.spring(duration: 0.3)) {
            onMove(dragged, targetID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if !isDragActive { isDragActive = true }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItemID = nil
        isDragActive = false
        return true
    }
}

/// 文のカード以外の場所へのドロップで状態を後始末する DropDelegate
private struct SentenceDropCleanupDelegate: DropDelegate {
    @Binding var draggedItemID: SentenceItem.ID?
    @Binding var isDragActive: Bool

    func validateDrop(info: DropInfo) -> Bool {
        draggedItemID != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if !isDragActive { isDragActive = true }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItemID = nil
        isDragActive = false
        return true
    }
}
