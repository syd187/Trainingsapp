import SwiftUI

struct MonthCalendarScreen: View {
    let referenceDate: Date
    let itemsForDate: (Date) -> [PlannedDayItem]
    let statusesForDate: (Date) -> [DayStatusModel]
    let nightOutsForDate: (Date) -> [DayContextEventModel]
    let hasProgressPhoto: (Date) -> Bool
    let dayTapped: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(referenceDate.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.periwinkle)

            HStack {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, name in
                    Text(name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.54))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(monthGrid.enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(
                            date: date,
                            items: itemsForDate(date),
                            statuses: statusesForDate(date),
                            nightOuts: nightOutsForDate(date),
                            hasProgressPhoto: hasProgressPhoto(date),
                            action: { dayTapped(date) }
                        )
                    } else {
                        Color.clear.frame(height: 92)
                    }
                }
            }
        }
    }

    private var monthGrid: [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: referenceDate),
              let dayRange = calendar.range(of: .day, in: .month, for: referenceDate)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        var result = Array<Date?>(repeating: nil, count: firstWeekday - 1)
        for day in dayRange {
            var components = calendar.dateComponents([.year, .month], from: referenceDate)
            components.day = day
            result.append(calendar.date(from: components))
        }
        return result
    }
}
