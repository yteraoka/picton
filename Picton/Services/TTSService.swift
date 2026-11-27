import AVFoundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.yteraoka.Picton",
    category: "TTSService"
)

/// 読み上げサービス
///
/// 状態（isSpeaking など）は UI から読むため、メインアクターに隔離する。
/// AVSpeechSynthesizer のデリゲートはどのスレッドから呼ばれるか決まっていないので、
/// `nonisolated` で受けてメインアクターに移ってから状態を更新する (#62)。
@MainActor
@Observable
final class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking = false

    /// 日本語音声が端末に用意されておらず読み上げできなかった場合に true。
    /// 読み上げを試みるたびにリセットされるため、UI 側は変化を監視して案内を出す。
    var isJapaneseVoiceUnavailable = false

    /// 読み上げを行うか
    ///
    /// UI テストでは無効にする。CI のシミュレータでは初回の読み上げで
    /// メインスレッドが 20〜30 秒止まり、その間の操作が取りこぼされてテストが不安定になるため。
    /// 音声はテストで検証できないので、テストの対象外として切り離す。
    private let isEnabled: Bool

    /// 最後に読み上げを開始した utterance。
    /// 前の読み上げを止めて次を始めると、前の utterance の didCancel が
    /// 新しい読み上げの開始後に届くため、それを無視するために使う (#59)。
    @ObservationIgnored private var utterances = UtteranceTracker<AVSpeechUtterance>()

    init(isEnabled: Bool = !Constants.isUITesting) {
        self.isEnabled = isEnabled
        super.init()
        synthesizer.delegate = self
        if isEnabled {
            configureAudioSession()
        }
    }

    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }

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

        utterances.begin(utterance)
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

    // utterance（Sendable ではない）そのものはメインアクターに渡さず、識別子だけを渡す。
    // 通知の順序が前後しても、トラッカーが最後に開始した utterance 以外を無視するので安全。

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, self.utterances.isCurrent(id) else { return }
            self.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.handleEnd(of: id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.handleEnd(of: id) }
    }

    /// 読み上げの完了・キャンセル時の後始末。
    /// 既に次の読み上げを始めている場合（古い utterance の通知）は何もしない。
    private func handleEnd(of utterance: ObjectIdentifier) {
        guard utterances.end(utterance) else { return }
        isSpeaking = false
        deactivateAudioSession()
    }
}

/// 最後に開始した読み上げを追跡し、それ以外の（古い）読み上げの通知を判別する。
///
/// 対象を強参照で保持するため、解放後に同じアドレスの別オブジェクトと
/// 取り違えることはない。
struct UtteranceTracker<Item: AnyObject> {
    private(set) var current: Item?

    /// 新しい読み上げを開始した
    mutating func begin(_ item: Item) {
        current = item
    }

    /// `item` が最後に開始した読み上げか
    func isCurrent(_ item: Item) -> Bool {
        isCurrent(ObjectIdentifier(item))
    }

    /// 識別子が `id` の読み上げが、最後に開始した読み上げか
    ///
    /// `current` を強参照で保持しているので、同じ識別子を持つ別のオブジェクトと取り違えることはない。
    func isCurrent(_ id: ObjectIdentifier) -> Bool {
        guard let current else { return false }
        return ObjectIdentifier(current) == id
    }

    /// `item` の読み上げが終わった。最後に開始した読み上げなら追跡を終えて true を返す。
    /// 古い読み上げの通知なら何もせず false を返す。
    mutating func end(_ item: Item) -> Bool {
        end(ObjectIdentifier(item))
    }

    /// 識別子が `id` の読み上げが終わった（`end(_ item:)` と同じ）
    mutating func end(_ id: ObjectIdentifier) -> Bool {
        guard isCurrent(id) else { return false }
        current = nil
        return true
    }
}
