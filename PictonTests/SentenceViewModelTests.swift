import Testing
@testable import Picton

@Suite("SentenceViewModel")
struct SentenceViewModelTests {
    private func makeViewModel(_ names: [String]) -> SentenceViewModel {
        let vm = SentenceViewModel()
        for name in names {
            vm.append(PictureCard(displayName: name, kanaText: name.lowercased(), category: "人"))
        }
        return vm
    }

    private func names(_ vm: SentenceViewModel) -> [String] {
        vm.cards.map(\.displayName)
    }

    @Test func appendAndFullKanaText() {
        let vm = makeViewModel(["A", "B", "C"])
        #expect(!vm.isEmpty)
        #expect(vm.fullKanaText() == "a b c")
    }

    @Test func removeAtIndex() {
        let vm = makeViewModel(["A", "B", "C"])
        vm.remove(at: 1)
        #expect(names(vm) == ["A", "C"])
    }

    @Test(arguments: [-1, 3, 100])
    func removeOutOfRangeIsIgnored(index: Int) {
        let vm = makeViewModel(["A", "B", "C"])
        vm.remove(at: index)
        #expect(names(vm) == ["A", "B", "C"])
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
}
