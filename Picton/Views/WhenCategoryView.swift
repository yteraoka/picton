import SwiftUI

struct WhenCategoryView: View {
    let isInteractive: Bool
    let onCardTap: (PictureCard) -> Void

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: today)! }
    private var dayAfterTomorrow: Date { Calendar.current.date(byAdding: .day, value: 2, to: today)! }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // きょう・あした・あさって
                HStack(spacing: 12) {
                    presetButton("きょう", kana: "きょう", symbol: "sun.max.fill", date: today)
                    presetButton("あした", kana: "あした", symbol: "moon.stars.fill", date: tomorrow)
                    presetButton("あさって", kana: "あさって", symbol: "calendar.badge.plus", date: dayAfterTomorrow)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 16)

                // カスタムカレンダー
                CalendarGridView(selectedDate: $selectedDate)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)

                // 選択日付カード
                let card = cardForSelectedDate(selectedDate)
                VStack(alignment: .leading, spacing: 8) {
                    Text("選択した日付")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)

                    Button {
                        onCardTap(card)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: card.presetImageName ?? "calendar")
                                .font(.title3)
                                .foregroundStyle(categoryColor(for: "いつ"))
                                .frame(width: 40, height: 40)
                                .background(categoryColor(for: "いつ").opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.displayName)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(card.kanaText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(categoryColor(for: "いつ"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(categoryColor(for: "いつ").opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(categoryColor(for: "いつ").opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 20)
            }
        }
        .disabled(!isInteractive)
    }

    @ViewBuilder
    private func presetButton(_ displayName: String, kana: String, symbol: String, date: Date) -> some View {
        let color = categoryColor(for: "いつ")
        Button {
            let card = PictureCard(
                displayName: displayName,
                kanaText: kana,
                category: "いつ",
                isPreset: true,
                presetImageName: symbol
            )
            onCardTap(card)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 56, height: 56)

                Text(displayName)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)

                Text(dateSubtitle(for: date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(displayName)
        .accessibilityHint("タップして文に追加")
    }

    private func dateSubtitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    private func cardForSelectedDate(_ date: Date) -> PictureCard {
        let d = Calendar.current.startOfDay(for: date)
        if d == today {
            return PictureCard(displayName: "きょう", kanaText: "きょう", category: "いつ",
                               isPreset: true, presetImageName: "sun.max.fill")
        } else if d == tomorrow {
            return PictureCard(displayName: "あした", kanaText: "あした", category: "いつ",
                               isPreset: true, presetImageName: "moon.stars.fill")
        } else if d == dayAfterTomorrow {
            return PictureCard(displayName: "あさって", kanaText: "あさって", category: "いつ",
                               isPreset: true, presetImageName: "calendar.badge.plus")
        }
        return makeDateCard(for: date)
    }

    private func makeDateCard(for date: Date) -> PictureCard {
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        return PictureCard(
            displayName: "\(month)月\(day)日",
            kanaText: dateKana(month: month, day: day),
            category: "いつ",
            isPreset: true,
            presetImageName: "calendar"
        )
    }

    private func dateKana(month: Int, day: Int) -> String {
        "\(monthReading(month)) \(dayReading(day))"
    }

    private func monthReading(_ month: Int) -> String {
        let readings = [
            "", "いちがつ", "にがつ", "さんがつ", "しがつ", "ごがつ", "ろくがつ",
            "しちがつ", "はちがつ", "くがつ", "じゅうがつ", "じゅういちがつ", "じゅうにがつ"
        ]
        return month >= 1 && month <= 12 ? readings[month] : "\(month)がつ"
    }

    private func dayReading(_ day: Int) -> String {
        let special: [Int: String] = [
            1: "ついたち", 2: "ふつか", 3: "みっか", 4: "よっか", 5: "いつか",
            6: "むいか", 7: "なのか", 8: "ようか", 9: "ここのか", 10: "とおか",
            14: "じゅうよっか", 20: "はつか", 24: "にじゅうよっか"
        ]
        if let s = special[day] { return s }
        return numberKana(day) + "にち"
    }

    private func numberKana(_ n: Int) -> String {
        let units = ["", "いち", "に", "さん", "し", "ご", "ろく", "しち", "はち", "く"]
        if n <= 9 { return units[n] }
        if n == 10 { return "じゅう" }
        let tens = n / 10
        let ones = n % 10
        let tensStr = tens == 1 ? "じゅう" : units[tens] + "じゅう"
        return tensStr + (ones > 0 ? units[ones] : "")
    }
}

// MARK: - カスタムカレンダーグリッド

private struct CalendarGridView: View {
    @Binding var selectedDate: Date

    @State private var displayedMonth: Date = {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        return Calendar.current.date(from: comps)!
    }()

    private static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ja_JP")
        c.firstWeekday = 1  // 日曜始まり
        return c
    }()
    private var cal: Calendar { Self.cal }

    private let holidayChecker = JapaneseHolidayChecker()
    private let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(spacing: 6) {
            // 月ナビゲーション
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle(for: displayedMonth))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // 曜日ヘッダー
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { col in
                    Text(weekdayLabels[col])
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(col == 0 ? .red : col == 6 ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日付グリッド
            let days = calendarDays(for: displayedMonth)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<days.count, id: \.self) { i in
                    if let date = days[i] {
                        DayCell(
                            date: date,
                            selectedDate: $selectedDate,
                            cal: cal,
                            columnIndex: i % 7,
                            isHoliday: holidayChecker.isHoliday(date)
                        )
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
    }

    private func monthTitle(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    private func changeMonth(by value: Int) {
        if let next = cal.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = next
        }
    }

    private func calendarDays(for month: Date) -> [Date?] {
        let comps = cal.dateComponents([.year, .month], from: month)
        guard let startOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: startOfMonth) else { return [] }

        let firstWeekday = cal.component(.weekday, from: startOfMonth)  // 1=日, ..., 7=土
        let offset = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in 0..<range.count {
            days.append(cal.date(byAdding: .day, value: day, to: startOfMonth))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

private struct DayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let cal: Calendar
    let columnIndex: Int  // 0=日曜, 6=土曜
    let isHoliday: Bool

    private var today: Date { cal.startOfDay(for: Date()) }
    private var isToday: Bool { cal.startOfDay(for: date) == today }
    private var isSelected: Bool { cal.startOfDay(for: date) == cal.startOfDay(for: selectedDate) }
    private var dayNumber: Int { cal.component(.day, from: date) }

    private var textColor: Color {
        if isSelected { return .white }
        if columnIndex == 0 || isHoliday { return .red }  // 日曜・祝日
        if columnIndex == 6 { return .blue }              // 土曜
        return .primary
    }

    var body: some View {
        Button {
            selectedDate = cal.startOfDay(for: date)
        } label: {
            Text("\(dayNumber)")
                .font(.system(size: 15))
                .fontWeight(isToday || isSelected ? .bold : .regular)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    Group {
                        if isSelected {
                            Circle()
                                .fill(categoryColor(for: "いつ"))
                                .padding(2)
                        } else if isToday {
                            Circle()
                                .strokeBorder(categoryColor(for: "いつ"), lineWidth: 1.5)
                                .padding(2)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dayNumber)日\(isHoliday ? "（祝日）" : "")")
    }
}

// MARK: - 日本の祝日計算

private struct JapaneseHolidayChecker {

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
