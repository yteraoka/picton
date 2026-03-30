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

                // 選択日付カード（きょう/あした/あさって以外）
                if !isPresetDate(selectedDate) {
                    let card = makeDateCard(for: selectedDate)
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
                                Image(systemName: "calendar")
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

    private func isPresetDate(_ date: Date) -> Bool {
        let d = Calendar.current.startOfDay(for: date)
        return d == today || d == tomorrow || d == dayAfterTomorrow
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
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps)!
    }()

    private static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ja_JP")
        c.firstWeekday = 1  // 日曜始まり
        return c
    }()
    private var cal: Calendar { Self.cal }

    // 日・月・火・水・木・金・土
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
                            columnIndex: i % 7
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

        // firstWeekday=1(日曜)なので、weekday値がそのままカラムインデックス
        let firstWeekday = cal.component(.weekday, from: startOfMonth) // 1=日, 2=月, ..., 7=土
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

    private var today: Date { cal.startOfDay(for: Date()) }
    private var isToday: Bool { cal.startOfDay(for: date) == today }
    private var isSelected: Bool { cal.startOfDay(for: date) == cal.startOfDay(for: selectedDate) }
    private var dayNumber: Int { cal.component(.day, from: date) }

    private var textColor: Color {
        if isSelected { return .white }
        if columnIndex == 0 { return .red }    // 日曜
        if columnIndex == 6 { return .blue }   // 土曜
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
        .accessibilityLabel("\(dayNumber)日")
    }
}
