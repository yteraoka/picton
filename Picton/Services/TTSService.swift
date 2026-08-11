import AVFoundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.yteraoka.Picton",
    category: "TTSService"
)

@Observable
final class TTSService: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private nonisolated(unsafe) let synthesizer = AVSpeechSynthesizer()
    var isSpeaking = false

    /// 日本語音声が端末に用意されておらず読み上げできなかった場合に true。
    /// 読み上げを試みるたびにリセットされるため、UI 側は変化を監視して案内を出す。
    var isJapaneseVoiceUnavailable = false

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        isJapaneseVoiceUnavailable = false
        guard let voice = preferredJapaneseVoice() else {
            logger.error("No \(Constants.ttsLanguage, privacy: .public) voice is installed on this device")
            isJapaneseVoiceUnavailable = true
            return
        }

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Constants.ttsRate

        activateAudioSession()
        synthesizer.speak(utterance)
    }

    private func preferredJapaneseVoice() -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == Constants.ttsLanguage }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
            .first
        ?? AVSpeechSynthesisVoice(language: Constants.ttsLanguage)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Audio Session

    /// カテゴリのみ設定する。ここではアクティブ化しない。
    /// 起動しただけで他アプリが再生中の音楽を止めてしまうのを避けるため、
    /// アクティブ化は読み上げ開始時、非アクティブ化は読み上げ終了時に行う。
    ///
    /// - `.playback`: サイレントスイッチが ON でも読み上げる（本アプリの要件）
    /// - `.spokenAudio`: 音声読み上げ向けの最適化
    /// - `.duckOthers`: 他アプリの音を止めずに音量を下げるだけにする
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
        } catch {
            logger.error("Failed to configure audio session: \(error)")
        }
    }

    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("Failed to activate audio session: \(error)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Failed to deactivate audio session: \(error)")
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.deactivateAudioSession()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.deactivateAudioSession()
        }
    }
}
