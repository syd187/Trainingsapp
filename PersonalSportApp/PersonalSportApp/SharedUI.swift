import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct AppNotice: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

struct PlannedTrainingRow: View {
    let item: PlannedDayItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind == .strength ? "dumbbell.fill" : item.kind == .simpleActivity ? "figure.climbing" : "heart.text.square.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.periwinkle)
                .frame(width: 34, height: 34)
                .background(AppColors.blueberry.opacity(0.46), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(item.workoutName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                Text(item.timeText ?? item.kind.title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.64))
            }
            Spacer()
        }
        .padding(12)
        .background(AppColors.midnight.opacity(0.36), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct DayCell: View {
    let date: Date
    let items: [PlannedDayItem]
    let statuses: [DayStatusModel]
    let nightOuts: [DayContextEventModel]
    let hasProgressPhoto: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Calendar.current.isDateInToday(date) ? AppColors.midnight : AppColors.periwinkle)

                ForEach(labels.prefix(2), id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(Calendar.current.isDateInToday(date) ? AppColors.midnight.opacity(0.72) : AppColors.periwinkle.opacity(0.78))
                }
                if labels.count > 2 {
                    Text("+\(labels.count - 2)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Calendar.current.isDateInToday(date) ? AppColors.midnight : AppColors.periwinkle)
                }
                if hasProgressPhoto {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Calendar.current.isDateInToday(date) ? AppColors.midnight : AppColors.periwinkle)
                }
                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 92)
            .background(Calendar.current.isDateInToday(date) ? AppColors.periwinkle : AppColors.indigo.opacity(0.78), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var labels: [String] {
        statuses.map { $0.type.title } + nightOuts.map { _ in "Night Out" } + items.map(\.workoutName)
    }
}

struct MiniPlayer: View {
    let session: TrainingSessionModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle().fill(AppColors.periwinkle).frame(width: 8, height: 8)
                Text(session.workoutName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer()
                TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                    Text(formatElapsed(context.date.timeIntervalSince(session.startedAt)))
                        .monospacedDigit()
                }
                Image(systemName: "arrow.up")
            }
            .foregroundStyle(AppColors.periwinkle)
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppColors.periwinkle.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ActionTile: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(AppColors.periwinkle)
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .background(AppColors.indigo.opacity(0.88), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MetricBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.periwinkle.opacity(0.58))
            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.periwinkle)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.indigo.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MetricLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
    }
}

enum AppColors {
    static let midnight = adaptiveColor(
        light: Color(red: 0.957, green: 0.973, blue: 0.992),
        dark: Color(red: 0.118, green: 0.122, blue: 0.149)
    )
    static let indigo = adaptiveColor(
        light: .white,
        dark: Color(red: 0.157, green: 0.212, blue: 0.333)
    )
    static let blueberry = adaptiveColor(
        light: Color(red: 0.302, green: 0.392, blue: 0.553),
        dark: Color(red: 0.302, green: 0.392, blue: 0.553)
    )
    static let periwinkle = adaptiveColor(
        light: Color(red: 0.118, green: 0.122, blue: 0.149),
        dark: Color(red: 0.816, green: 0.882, blue: 0.976)
    )

    private static func adaptiveColor(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        dark
        #endif
    }
}

extension View {
    func panel() -> some View {
        self
            .padding(16)
            .background(AppColors.indigo.opacity(0.88), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColors.blueberry.opacity(0.34), lineWidth: 1))
    }

    func sectionTitle() -> some View {
        self
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.periwinkle)
    }

    func subsectionTitle() -> some View {
        self
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.periwinkle.opacity(0.72))
    }

    func miniLabel() -> some View {
        self
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.periwinkle.opacity(0.64))
    }

    func primaryButton() -> some View {
        self
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.midnight)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppColors.periwinkle, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension WeeklySlotModel {
    var weekdayName: String { weekday.weekdayName }
    var timeText: String? {
        guard let hour, let minute else { return nil }
        return String(format: "%02d:%02d", hour, minute)
    }
}

extension WorkoutModel {
    var plannedItem: PlannedDayItem {
        PlannedDayItem(id: id.uuidString, date: .now, workoutId: id, workoutName: name, kind: kind, hour: nil, minute: nil, isPostponed: false)
    }
}

extension Int {
    var weekdayName: String {
        switch self {
        case 1: "Sunday"
        case 2: "Monday"
        case 3: "Tuesday"
        case 4: "Wednesday"
        case 5: "Thursday"
        case 6: "Friday"
        case 7: "Saturday"
        default: "Day"
        }
    }
}

extension Double {
    var kgText: String {
        String(format: "%.1f kg", self)
    }

    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension String {
    func boolArray(count: Int) -> [Bool] {
        var values = map { $0 == "1" }
        if values.count < count {
            values.append(contentsOf: Array(repeating: false, count: count - values.count))
        }
        return Array(values.prefix(count))
    }
}

extension Array where Element == Bool {
    var maskString: String {
        map { $0 ? "1" : "0" }.joined()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

func formatElapsed(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}
