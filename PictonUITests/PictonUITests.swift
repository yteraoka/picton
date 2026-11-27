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

    /// 前後のカテゴリも画面外に描画されているため、操作できるものを選ぶ
    private func card(_ name: String) -> XCUIElement {
        app.buttons.matching(identifier: name).allElementsBoundByIndex.first { $0.isHittable }
            ?? app.buttons[name].firstMatch
    }

    private func selectCategory(_ category: String) {
        let tab = app.buttons["\(category)カテゴリ"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        XCTAssertTrue(card("くるま").waitForExistence(timeout: 5))
    }

    func testAddCardsToSentenceAndClear() {
        selectCategory("手段")

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
        selectCategory("手段")
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
            self.card("電車").frame.minX < self.card("くるま").frame.minX
        }
        let expectation = XCTNSPredicateExpectation(predicate: swapped, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, "電車 → くるま の順に並べ替わっていない")

        app.buttons["編集モード終了"].tap()
        XCTAssertTrue(app.buttons["編集モード"].waitForExistence(timeout: 3))
        XCTAssertLessThan(card("電車").frame.minX, card("くるま").frame.minX, "編集モード終了後も並び順が保たれる")
    }
}
