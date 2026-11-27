import Foundation
import Testing
@testable import Picton

@Suite("JapaneseHolidayChecker")
struct JapaneseHolidayCheckerTests {
    let checker = JapaneseHolidayChecker()
    let cal = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// 指定年の全日を走査して祝日（"M/d" 形式）を列挙する
    private func holidays(in year: Int) -> [String] {
        var result: [String] = []
        var day = date(year, 1, 1)
        while cal.component(.year, from: day) == year {
            if checker.isHoliday(day) {
                let c = cal.dateComponents([.month, .day], from: day)
                result.append("\(c.month!)/\(c.day!)")
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    // 内閣府「国民の祝日」の一覧と一致すること
    @Test func holidaysIn2025() {
        #expect(holidays(in: 2025) == [
            "1/1", "1/13", "2/11", "2/23", "2/24", "3/20", "4/29",
            "5/3", "5/4", "5/5", "5/6", "7/21", "8/11", "9/15", "9/23",
            "10/13", "11/3", "11/23", "11/24",
        ])
    }

    @Test func holidaysIn2026() {
        #expect(holidays(in: 2026) == [
            "1/1", "1/12", "2/11", "2/23", "3/20", "4/29",
            "5/3", "5/4", "5/5", "5/6", "7/20", "8/11", "9/21", "9/22", "9/23",
            "10/12", "11/3", "11/23",
        ])
    }

    @Test func substituteHolidayAfterSundayHoliday() {
        #expect(checker.isHoliday(date(2023, 1, 2)))   // 元日が日曜
        #expect(checker.isHoliday(date(2024, 8, 12)))  // 山の日が日曜
        #expect(checker.isHoliday(date(2027, 3, 22)))  // 春分の日が日曜
    }

    @Test func substituteHolidaySkipsConsecutiveHolidays() {
        // 2026/5/3(日) 憲法記念日 → 5/4, 5/5 も祝日なので振替は 5/6(水)
        #expect(checker.isHoliday(date(2026, 5, 6)))
        #expect(!checker.isHoliday(date(2026, 5, 7)))
    }

    @Test func citizensHolidayBetweenHolidays() {
        // 2026/9/21 敬老の日 と 9/23 秋分の日 に挟まれた 9/22
        #expect(checker.isHoliday(date(2026, 9, 22)))
    }

    @Test func emperorsBirthdayStartsIn2020() {
        #expect(!checker.isHoliday(date(2019, 2, 25)))  // 2019/2/23 は土曜だが当時は祝日ではない
        #expect(checker.isHoliday(date(2020, 2, 24)))   // 2020/2/23(日) の振替
    }

    @Test func ordinaryDaysAreNotHolidays() {
        #expect(!checker.isHoliday(date(2026, 11, 26)))  // 平日
        #expect(!checker.isHoliday(date(2026, 11, 29)))  // ただの日曜
        #expect(!checker.isHoliday(date(2026, 12, 23)))  // 旧天皇誕生日
    }
}
