import XCTest

final class PictonUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // アプリ側でメモリ上のストアを使い、毎回プリセットだけの初期状態から始める
        app.launchArguments = ["--uitesting"]
        app.launch()
        dismissVoiceAlertIfNeeded()
    }

    /// 日本語音声が未インストールの環境（CI など）で出る案内を閉じる
    private func dismissVoiceAlertIfNeeded() {
        let alert = app.alerts["日本語の音声が見つかりません"]
        if alert.waitForExistence(timeout: 2) {
            alert.buttons["OK"].tap()
        }
    }

    /// 画面内にあるカードを返す
    ///
    /// 前後のカテゴリも画面外に描画されているため、同じラベルの要素が複数ある。
    /// `isHittable` はカテゴリ切り替えのアニメーション中の要素や画面外の要素に対して
    /// false を返さず「Activation point invalid」でテストを失敗させるので使わず、
    /// フレームの中心がウィンドウ内にあるかで判定する。
    private func onScreenCard(_ name: String) -> XCUIElement? {
        let window = app.windows.firstMatch.frame
        return app.buttons.matching(identifier: name).allElementsBoundByIndex.first { element in
            let frame = element.frame
            return !frame.isEmpty && window.contains(CGPoint(x: frame.midX, y: frame.midY))
        }
    }

    private func card(_ name: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        guard let element = onScreenCard(name) else {
            XCTFail("「\(name)」が画面内に見つからない", file: file, line: line)
            return app.buttons[name].firstMatch
        }
        return element
    }

    /// カードが画面内に現れ、位置が止まる（アニメーションが終わる）まで待つ
    private func waitForCardToSettle(_ name: String, timeout: TimeInterval = 10) -> Bool {
        var lastFrame: CGRect?
        let settled = NSPredicate { _, _ in
            guard let frame = self.onScreenCard(name)?.frame else {
                lastFrame = nil
                return false
            }
            defer { lastFrame = frame }
            return frame == lastFrame
        }
        let expectation = XCTNSPredicateExpectation(predicate: settled, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func selectCategory(_ category: String, expecting cardName: String) {
        let tab = app.buttons["\(category)カテゴリ"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        XCTAssertTrue(waitForCardToSettle(cardName), "「\(category)」カテゴリに切り替わっていない")
    }

    func testAddCardsToSentenceAndClear() {
        selectCategory("手段", expecting: "くるま")

        card("くるま").tap()
        card("電車").tap()
        XCTAssertTrue(app.buttons["くるまを削除"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["電車を削除"].exists)

        // 文中のカードをタップすると 1 枚だけ消える
        app.buttons["くるまを削除"].tap()
        XCTAssertFalse(app.buttons["くるまを削除"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["電車を削除"].exists)

        app.buttons["すべて消す"].tap()
        XCTAssertFalse(app.buttons["電車を削除"].waitForExistence(timeout: 1))
    }

    /// PR #32: 編集モードでドラッグするとリアルタイムに並べ替わる
    func testReorderByDragInEditMode() {
        selectCategory("手段", expecting: "くるま")
        app.buttons["編集モード"].tap()
        XCTAssertTrue(app.buttons["編集モード終了"].waitForExistence(timeout: 3))

        let car = card("くるま")
        let train = card("電車")
        XCTAssertLessThan(car.frame.minX, train.frame.minX, "初期状態では くるま → 電車 の順")

        let start = car.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = train.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 1.5, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 1.0)

        // ドロップ後のアニメーションを待ってから位置を比べる
        let swapped = NSPredicate { _, _ in
            guard let train = self.onScreenCard("電車"), let car = self.onScreenCard("くるま") else { return false }
            return train.frame.minX < car.frame.minX
        }
        let expectation = XCTNSPredicateExpectation(predicate: swapped, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, "電車 → くるま の順に並べ替わっていない")

        app.buttons["編集モード終了"].tap()
        XCTAssertTrue(app.buttons["編集モード"].waitForExistence(timeout: 3))
        XCTAssertLessThan(card("電車").frame.minX, card("くるま").frame.minX, "編集モード終了後も並び順が保たれる")
    }
}
