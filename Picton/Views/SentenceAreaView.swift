import SwiftUI

struct SentenceAreaView: View {
    var sentenceVM: SentenceViewModel
    let ttsService: TTSService

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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sentenceVM.items) { item in
                        SentenceCardView(card: item.card) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sentenceVM.remove(id: item.id)
                            }
                        }
                        .draggable(item.id.uuidString) {
                            SentenceCardView(card: item.card, onRemove: {})
                                .opacity(0.8)
                        }
                        .dropDestination(for: String.self) { droppedIDs, _ in
                            guard let idString = droppedIDs.first,
                                  let sourceIndex = sentenceVM.items.firstIndex(where: { $0.id.uuidString == idString }),
                                  let targetIndex = sentenceVM.items.firstIndex(where: { $0.id == item.id }) else {
                                return false
                            }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sentenceVM.move(from: sourceIndex, to: targetIndex)
                            }
                            return true
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if !sentenceVM.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sentenceVM.clear()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("すべて消す")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: Constants.sentenceAreaHeight)
        .background(Constants.Colors.sentenceAreaBackground)
    }
}
