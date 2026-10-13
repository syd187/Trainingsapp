import Charts
import SwiftUI

struct ProgressScreen: View {
    let weights: [BodyWeightEntryModel]
    let rollingWeight: Double?
    let addWeightAction: () -> Void
    @State private var range = "1M"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: addWeightAction) {
                Label("Gewicht eintragen", systemImage: "plus.circle.fill")
                    .primaryButton()
            }

            HStack(spacing: 12) {
                MetricBox(title: "Latest", value: weights.first.map { String(format: "%.1f kg", $0.weightKg) } ?? "-")
                MetricBox(title: "7-day avg", value: rollingWeight.map { String(format: "%.1f kg", $0) } ?? "-")
            }
            Picker("Range", selection: $range) {
                ForEach(["1M", "3M", "6M", "1Y", "All"], id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)

            Chart(filteredWeights) { entry in
                LineMark(
                    x: .value("Date", entry.measuredAt),
                    y: .value("Weight", entry.weightKg)
                )
                PointMark(
                    x: .value("Date", entry.measuredAt),
                    y: .value("Weight", entry.weightKg)
                )
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 260)
            .padding()
            .background(AppColors.indigo.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var filteredWeights: [BodyWeightEntryModel] {
        let days: Int? = switch range {
        case "1M": 31
        case "3M": 92
        case "6M": 183
        case "1Y": 365
        default: nil
        }
        guard let days, let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return Array(weights.reversed()) }
        return Array(weights.filter { $0.measuredAt >= cutoff }.reversed())
    }
}

