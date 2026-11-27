import Foundation

/// 日本の祝日計算（振替休日・国民の休日を含む）
struct JapaneseHolidayChecker {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ja_JP")
        c.firstWeekday = 1
        return c
    }()

    func isHoliday(_ date: Date) -> Bool {
        isBaseHoliday(date) || isSubstituteHoliday(date) || isCitizensHoliday(date)
    }

    // 基本祝日
    private func isBaseHoliday(_ date: Date) -> Bool {
        baseHolidayName(for: date) != nil
    }

    private func baseHolidayName(for date: Date) -> String? {
        let comps = cal.dateComponents([.year, .month, .day, .weekday], from: date)
        guard let year = comps.year, let month = comps.month,
              let day = comps.day, let weekday = comps.weekday else { return nil }

        switch month {
        case 1:
            if day == 1 { return "元日" }
            if weekday == 2, (8...14).contains(day) { return "成人の日" }      // 第2月曜
        case 2:
            if day == 11 { return "建国記念の日" }
            if day == 23, year >= 2020 { return "天皇誕生日" }
        case 3:
            if day == springEquinox(year: year) { return "春分の日" }
        case 4:
            if day == 29 { return "昭和の日" }
        case 5:
            if day == 3 { return "憲法記念日" }
            if day == 4 { return "みどりの日" }
            if day == 5 { return "こどもの日" }
        case 7:
            if weekday == 2, (15...21).contains(day) { return "海の日" }       // 第3月曜
        case 8:
            if day == 11 { return "山の日" }
        case 9:
            if weekday == 2, (15...21).contains(day) { return "敬老の日" }     // 第3月曜
            if day == autumnEquinox(year: year) { return "秋分の日" }
        case 10:
            if weekday == 2, (8...14).contains(day) { return "スポーツの日" }  // 第2月曜
        case 11:
            if day == 3 { return "文化の日" }
            if day == 23 { return "勤労感謝の日" }
        default:
            break
        }
        return nil
    }

    // 振替休日: 基本祝日が日曜→翌日以降で連続する基本祝日をスキップした最初の平日
    private func isSubstituteHoliday(_ date: Date) -> Bool {
        let weekday = cal.component(.weekday, from: date)
        guard weekday != 1, !isBaseHoliday(date) else { return false }

        // 前日から遡り、連続する基本祝日の先頭が日曜かを確認
        var cursor = date
        while let prev = cal.date(byAdding: .day, value: -1, to: cursor) {
            let prevWeekday = cal.component(.weekday, from: prev)
            if prevWeekday == 1 {
                return isBaseHoliday(prev)
            }
            if isBaseHoliday(prev) {
                cursor = prev
            } else {
                break
            }
        }
        return false
    }

    // 国民の休日: 前日・翌日がともに基本祝日に挟まれた平日
    private func isCitizensHoliday(_ date: Date) -> Bool {
        guard !isBaseHoliday(date) else { return false }
        let weekday = cal.component(.weekday, from: date)
        guard weekday != 1 else { return false }
        guard let prev = cal.date(byAdding: .day, value: -1, to: date),
              let next = cal.date(byAdding: .day, value: 1, to: date) else { return false }
        return isBaseHoliday(prev) && isBaseHoliday(next)
    }

    // 春分の日（1980〜2099年）
    private func springEquinox(year: Int) -> Int {
        Int(20.8431 + 0.242194 * Double(year - 1980) - Double((year - 1980) / 4))
    }

    // 秋分の日（1980〜2099年）
    private func autumnEquinox(year: Int) -> Int {
        Int(23.2488 + 0.242194 * Double(year - 1980) - Double((year - 1980) / 4))
    }
}
