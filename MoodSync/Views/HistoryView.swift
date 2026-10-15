import Charts
import SwiftUI
import MoodSyncCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var range: HistoryRange = .week

    private var entries: [MoodEntry] {
        HistoryChart.filtered(model.state.history, in: range)
    }

    private var points: [MoodEntry] {
        HistoryChart.dailyLatest(model.state.history, in: range)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Range", selection: $range) {
                    ForEach(HistoryRange.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if let average = HistoryStats.averageValence(entries) {
                    Text("This \(range.title.lowercased()) felt \(HistoryStats.word(for: average)).")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 16) {
                        stat("Check-ins", "\(entries.count)")
                        stat("Most often", HistoryStats.mostCommonLabel(entries) ?? "—")
                    }
                }

                if points.isEmpty {
                    ContentUnavailableView(
                        "No check-ins yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Set a mood on Home and it will land here.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    chart
                    if points.count <= 12 {
                        weekStrip
                    }
                    list
                }
            }
            .padding(20)
        }
        .navigationTitle("History")
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private var chart: some View {
        let tint = Theme.color(hex: points.last?.colorHex ?? MoodPreset.happy.colorHex)
        return Chart(points) { point in
            AreaMark(
                x: .value("Day", point.createdAt),
                y: .value("Level", point.valence)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [tint.opacity(0.38), tint.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            LineMark(
                x: .value("Day", point.createdAt),
                y: .value("Level", point.valence)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            PointMark(
                x: .value("Day", point.createdAt),
                y: .value("Level", point.valence)
            )
            .foregroundStyle(Theme.color(hex: point.colorHex))
            .symbolSize(70)
        }
        .chartYScale(domain: -1.15...1.15)
        .chartYAxis {
            AxisMarks(position: .leading, values: [-1, 0, 1]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number > 0.5 ? "High" : number < -0.5 ? "Low" : "Even")
                            .font(.system(.caption2, design: .rounded))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: axisFormat)
            }
        }
        .frame(height: 230)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        .accessibilityLabel("Mood chart")
    }

    private var weekStrip: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(points) { point in
                VStack(spacing: 4) {
                    Text(point.emoji)
                        .font(.title3)
                    Text(point.createdAt, format: .dateTime.weekday(.narrow))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(point.label) on \(point.createdAt.formatted(date: .abbreviated, time: .omitted))")
            }
        }
        .padding(.vertical, 8)
    }

    private var axisFormat: Date.FormatStyle {
        if range == .all {
            return .dateTime.month(.abbreviated).day()
        }
        return .dateTime.weekday(.narrow)
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(entries.reversed()) { entry in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text(entry.emoji)
                            .font(.title3)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.label)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            if !entry.note.isEmpty {
                                Text(entry.note)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Text(entry.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    if entry.id != entries.first?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }
}
