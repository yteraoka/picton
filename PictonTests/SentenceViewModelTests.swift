import Foundation
import Testing
@testable import Picton

@Suite("SentenceViewModel")
struct SentenceViewModelTests {
    private func snapshot(_ name: String, id: UUID? = UUID()) -> CardSnapshot {
        CardSnapshot(
            cardID: id,
            displayName: name,
            kanaText: name.lowercased(),
            category: "人",
            isPreset: false,
            presetImageName: nil
        )
    }

    private func makeViewModel(_ names: [String]) -> SentenceViewModel {
        let vm = SentenceViewModel()
        for name in names {
            vm.append(snapshot(name))
        }
        return vm
    }

    private func names(_ vm: SentenceViewModel) -> [String] {
        vm.items.map(\.card.displayName)
    }

    @Test func appendAndFullKanaText() {
        let vm = makeViewModel(["A", "B", "C"])
        #expect(!vm.isEmpty)
        #expect(vm.fullKanaText() == "a b c")
    }

    @Test func snapshotCopiesPictureCard() {
        let card = PictureCard(displayName: "A", kanaText: "えー", category: "人",
                               isPreset: true, presetImageName: "person.fill")
        let snap = CardSnapshot(card)
        #expect(snap.cardID == card.id)
        #expect(snap.displayName == "A")
        #expect(snap.kanaText == "えー")
        #expect(snap.category == "人")
        #expect(snap.isPreset)
        #expect(snap.presetImageName == "person.fill")
    }

    @Test func removeByID() {
        let vm = makeViewModel(["A", "B", "C"])
        vm.remove(id: vm.items[1].id)
        #expect(names(vm) == ["A", "C"])
    }

    @Test func removeUnknownIDIsIgnored() {
        let vm = makeViewModel(["A", "B", "C"])
        vm.remove(id: UUID())
        #expect(names(vm) == ["A", "B", "C"])
    }

    /// 同じカードを 2 回並べても要素ごとに ID が異なり、片方だけ削除できる (#58)
    @Test func sameCardAppendedTwiceHasDistinctIDs() {
        let vm = SentenceViewModel()
        let card = snapshot("A")
        vm.append(card)
        vm.append(card)
        #expect(vm.items.count == 2)
        #expect(vm.items[0].id != vm.items[1].id)

        vm.remove(id: vm.items[1].id)
        #expect(vm.items.count == 1)
        #expect(names(vm) == ["A"])
    }

    /// destination は List.onMove と同じく「移動前の配列における挿入位置」
    @Test(arguments: [
        (from: 0, to: 3, expected: ["B", "C", "A"]),
        (from: 0, to: 2, expected: ["B", "A", "C"]),
        (from: 2, to: 0, expected: ["C", "A", "B"]),
        (from: 1, to: 0, expected: ["B", "A", "C"]),
        (from: 0, to: 0, expected: ["A", "B", "C"]),
        (from: 0, to: 1, expected: ["A", "B", "C"]),
        (from: 0, to: 99, expected: ["B", "C", "A"]),  // 末尾にクランプ
        (from: 2, to: -5, expected: ["C", "A", "B"]),  // 先頭にクランプ
    ])
    func move(from: Int, to: Int, expected: [String]) {
        let vm = makeViewModel(["A", "B", "C"])
        vm.move(from: from, to: to)
        #expect(names(vm) == expected)
    }

    @Test(arguments: [-1, 3])
    func moveFromOutOfRangeIsIgnored(source: Int) {
        let vm = makeViewModel(["A", "B", "C"])
        vm.move(from: source, to: 0)
        #expect(names(vm) == ["A", "B", "C"])
    }

    @Test func clear() {
        let vm = makeViewModel(["A", "B"])
        vm.clear()
        #expect(vm.isEmpty)
        #expect(vm.fullKanaText() == "")
    }

    // MARK: - sync(with:) (#36)

    /// DB から削除されたカードは文エリアからも取り除かれる
    @Test func syncRemovesDeletedCards() {
        let a = snapshot("A"), b = snapshot("B")
        let vm = SentenceViewModel()
        vm.append(a)
        vm.append(b)
        vm.append(a)

        vm.sync(with: [b])
        #expect(names(vm) == ["B"])
    }

    /// 編集されたカードの表示名・読みが反映され、要素の ID と並び順は保たれる
    @Test func syncUpdatesEditedCards() {
        let id = UUID()
        let vm = SentenceViewModel()
        vm.append(snapshot("A", id: id))
        vm.append(snapshot("B"))
        let itemIDs = vm.items.map(\.id)
        let b = vm.items[1].card

        let edited = CardSnapshot(cardID: id, displayName: "A2", kanaText: "えーつー",
                                  category: "人", isPreset: false, presetImageName: nil)
        vm.sync(with: [edited, b])

        #expect(names(vm) == ["A2", "B"])
        #expect(vm.fullKanaText() == "えーつー b")
        #expect(vm.items.map(\.id) == itemIDs)
    }

    /// DB に存在しないカード（「いつ」の日付カードなど）は同期で消えない
    @Test func syncKeepsTransientCards() {
        let vm = SentenceViewModel()
        vm.append(snapshot("きょう", id: nil))
        vm.append(snapshot("A"))

        vm.sync(with: [])
        #expect(names(vm) == ["きょう"])
    }
}

// MARK: - 読み上げの追跡 (#59)

// 文の読み上げ（TTSService）が使う判定ロジック。
// 専用のテストファイルを追加するには xcodegen での再生成が必要なため、ここに置く。
@Suite("UtteranceTracker")
struct UtteranceTrackerTests {
    // #expect は式を分解してレシーバを不変値として評価するため、
    // mutating な end(_:) は結果を変数に受けてから検査する
    private final class Utterance {}

    @Test func endOfCurrentUtteranceFinishesTracking() {
        var tracker = UtteranceTracker<Utterance>()
        let a = Utterance()
        tracker.begin(a)
        #expect(tracker.isCurrent(a))
        let ended = tracker.end(a)
        #expect(ended)
        #expect(tracker.current == nil)
    }

    /// 連続タップ: A を止めて B を開始した後に A の didCancel が届いても、B の追跡は続く
    @Test func lateCancelOfPreviousUtteranceIsIgnored() {
        var tracker = UtteranceTracker<Utterance>()
        let a = Utterance(), b = Utterance()
        tracker.begin(a)
        tracker.begin(b)

        #expect(!tracker.isCurrent(a))
        let endedA = tracker.end(a)
        #expect(!endedA)
        #expect(tracker.current === b)

        let endedB = tracker.end(b)
        #expect(endedB)
        #expect(tracker.current == nil)
    }

    @Test func endIsIgnoredWhenNothingIsTracked() {
        var tracker = UtteranceTracker<Utterance>()
        let ended = tracker.end(Utterance())
        #expect(!ended)
    }

    @Test func secondEndOfSameUtteranceIsIgnored() {
        var tracker = UtteranceTracker<Utterance>()
        let a = Utterance()
        tracker.begin(a)
        let first = tracker.end(a)
        let second = tracker.end(a)
        #expect(first)
        #expect(!second)
    }
}
