import SwiftUI

struct PlaybackButtonView: View {
    let isSpeaking: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isSpeaking ? "stop.circle.fill" : "play.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(isSpeaking ? .red : .green)
                .accessibilityLabel(isSpeaking ? "読み上げを止める" : "読み上げる")
        }
    }
}
