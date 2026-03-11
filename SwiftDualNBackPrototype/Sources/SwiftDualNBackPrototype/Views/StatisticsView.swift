import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

private enum StreamSeries: String {
    case visual = "Visual"
    case audio = "Auditory"
}

private enum StatisticsChartTab: String, CaseIterable, Identifiable {
    case rawScores = "Raw Scores"
    case nLevel = "N-Level"

    var id: String { rawValue }
}

private struct RawScoreChartPoint: Identifiable {
    let id: String
    let sessionIndex: Int
    let accuracy: Double
    let series: StreamSeries
}

private struct DailyNLevelPoint: Identifiable {
    let dayIndex: Int
    let day: Date
    let averageNLevel: Double
    let sessionCount: Int

    var id: Int { dayIndex }
}

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    let onClearStatistics: () -> Void
    private let sortedSessions: [SessionScore]
    private let rawScoreChartPoints: [RawScoreChartPoint]
    private let dailyNLevelPoints: [DailyNLevelPoint]
    @State private var showClearConfirmation = false
    @State private var exportStatusMessage = ""
    @State private var selectedChartTab: StatisticsChartTab = .rawScores

    private static let csvTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let csvFilenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let chartSectionHeight: CGFloat = 270

    init(sessions: [SessionScore], onClearStatistics: @escaping () -> Void) {
        self.onClearStatistics = onClearStatistics
        self.sortedSessions = sessions.sorted { $0.completedAt < $1.completedAt }

        var points: [RawScoreChartPoint] = []
        points.reserveCapacity(self.sortedSessions.count * 2)
        for (index, session) in sortedSessions.enumerated() {
            let sessionIndex = index + 1
            points.append(
                .init(
                    id: "\(session.id.uuidString)-\(StreamSeries.visual.rawValue)",
                    sessionIndex: sessionIndex,
                    accuracy: session.visualAccuracy,
                    series: .visual
                )
            )
            points.append(
                .init(
                    id: "\(session.id.uuidString)-\(StreamSeries.audio.rawValue)",
                    sessionIndex: sessionIndex,
                    accuracy: session.audioAccuracy,
                    series: .audio
                )
            )
        }
        self.rawScoreChartPoints = points

        let calendar = Calendar.autoupdatingCurrent
        let sessionsByDay = Dictionary(grouping: self.sortedSessions) { session in
            calendar.startOfDay(for: session.completedAt)
        }
        self.dailyNLevelPoints = sessionsByDay.keys.sorted().enumerated().compactMap { offset, day in
            guard let daySessions = sessionsByDay[day], !daySessions.isEmpty else {
                return nil
            }

            let totalNLevel = daySessions.reduce(0.0) { partialResult, session in
                partialResult + Double(session.endN)
            }

            return DailyNLevelPoint(
                dayIndex: offset + 1,
                day: day,
                averageNLevel: totalNLevel / Double(daySessions.count),
                sessionCount: daySessions.count
            )
        }
    }

    private var savedStatusText: String {
        guard let lastUpdatedAt = sortedSessions.last?.completedAt else {
            return "Saved locally, no sessions yet."
        }
        return "Saved locally, last updated at \(lastUpdatedAt.formatted(.dateTime.year().month().day().hour().minute()))."
    }

    private var nLevelChartDomain: ClosedRange<Double> {
        guard
            let minValue = dailyNLevelPoints.map(\.averageNLevel).min(),
            let maxValue = dailyNLevelPoints.map(\.averageNLevel).max()
        else {
            return 1.0...2.0
        }

        let lowerBound = max(1.0, floor((minValue - 0.5) * 2.0) / 2.0)
        let upperBound = max(lowerBound + 1.0, ceil((maxValue + 0.5) * 2.0) / 2.0)
        return lowerBound...upperBound
    }

    private var nLevelAxisMarks: [Int] {
        guard !dailyNLevelPoints.isEmpty else { return [] }

        let desiredLabelCount = min(max(dailyNLevelPoints.count, 2), 7)
        let step = max(1, Int(ceil(Double(dailyNLevelPoints.count - 1) / Double(max(desiredLabelCount - 1, 1)))))

        var indices = Array(stride(from: 1, through: dailyNLevelPoints.count, by: step))
        if indices.last != dailyNLevelPoints.count {
            indices.append(dailyNLevelPoints.count)
        }
        return indices
    }

    private func dayLabel(for index: Int) -> String {
        guard let point = dailyNLevelPoints.first(where: { $0.dayIndex == index }) else {
            return ""
        }
        return point.day.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Statistics")
                .font(.title.bold())

            Text(savedStatusText)
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("Statistics Chart", selection: $selectedChartTab) {
                ForEach(StatisticsChartTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            if sortedSessions.isEmpty {
                Text("No saved sessions yet. Complete a run to create your first entry.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                Group {
                    switch selectedChartTab {
                    case .rawScores:
                        rawScoresChart
                    case .nLevel:
                        nLevelChart
                    }
                }

                List(sortedSessions.reversed()) { session in
                    HStack(spacing: 16) {
                        Text(session.completedAt, format: .dateTime.year().month().day().hour().minute())
                            .frame(minWidth: 180, alignment: .leading)
                        Text("N \(session.startN)->\(session.endN)")
                            .frame(minWidth: 70, alignment: .leading)
                        Text(String(format: "V %.1f%%", session.visualAccuracy))
                            .frame(minWidth: 80, alignment: .leading)
                        Text(String(format: "A %.1f%%", session.audioAccuracy))
                            .frame(minWidth: 80, alignment: .leading)
                        Text(String(format: "Avg %.1f%%", session.averageAccuracy))
                            .frame(minWidth: 90, alignment: .leading)
                    }
                    .font(.system(.body, design: .monospaced))
                }
                .frame(minHeight: 90, idealHeight: 220, maxHeight: .infinity)
            }

            HStack {
                Button("Export CSV") {
                    exportCSV()
                }
                .disabled(sortedSessions.isEmpty)

                Button("Clear Statistics Data", role: .destructive) {
                    showClearConfirmation = true
                }
                .disabled(sortedSessions.isEmpty)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            if !exportStatusMessage.isEmpty {
                Text(exportStatusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(minWidth: 760, idealWidth: 900, minHeight: 520, idealHeight: 640)
        .alert("Erase all score history?", isPresented: $showClearConfirmation) {
            Button("Erase", role: .destructive) {
                onClearStatistics()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes all saved session scores permanently.")
        }
    }

    private var rawScoresChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(rawScoreChartPoints) { point in
                    LineMark(
                        x: .value("Session", point.sessionIndex),
                        y: .value("Accuracy", point.accuracy),
                        series: .value("Stream", point.series.rawValue)
                    )
                    .foregroundStyle(by: .value("Stream", point.series.rawValue))
                }

                ForEach(rawScoreChartPoints) { point in
                    PointMark(
                        x: .value("Session", point.sessionIndex),
                        y: .value("Accuracy", point.accuracy)
                    )
                    .foregroundStyle(by: .value("Stream", point.series.rawValue))
                }
            }
            .chartForegroundStyleScale([
                StreamSeries.visual.rawValue: Color.blue,
                StreamSeries.audio.rawValue: Color.green,
            ])
            .chartYScale(domain: 0...100)
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 220)

            Text("Per-session visual and auditory accuracy for each completed run.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(height: chartSectionHeight, alignment: .top)
    }

    private var nLevelChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(dailyNLevelPoints) { point in
                    LineMark(
                        x: .value("Day", point.dayIndex),
                        y: .value("Average N-Level", point.averageNLevel)
                    )
                    .foregroundStyle(.orange)

                    PointMark(
                        x: .value("Day", point.dayIndex),
                        y: .value("Average N-Level", point.averageNLevel)
                    )
                    .foregroundStyle(.orange)
                    .annotation(position: .top, alignment: .center) {
                        if point.sessionCount > 1 {
                            Text("\(point.sessionCount)x")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: nLevelChartDomain)
            .chartXAxis {
                AxisMarks(values: nLevelAxisMarks) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let index = value.as(Int.self) {
                            Text(dayLabel(for: index))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)

            Text("Daily average of the N-level reached by the end of each session. Two sessions that finish at N=3 and N=4 on the same day plot as 3.5.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(height: chartSectionHeight, alignment: .top)
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.title = "Export Statistics as CSV"
        panel.prompt = "Export"
        panel.nameFieldStringValue = defaultCSVFilename()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType.commaSeparatedText]

        guard panel.runModal() == .OK, let url = panel.url else {
            exportStatusMessage = "CSV export cancelled."
            return
        }

        do {
            let csv = makeCSV(from: sortedSessions)
            try csv.write(to: url, atomically: true, encoding: .utf8)
            exportStatusMessage = "Exported CSV to \(url.lastPathComponent)."
        } catch {
            exportStatusMessage = "CSV export failed: \(error.localizedDescription)"
        }
    }

    private func makeCSV(from sessions: [SessionScore]) -> String {
        var lines: [String] = []
        lines.append(
            [
                "completed_at",
                "start_n",
                "end_n",
                "visual_accuracy_percent",
                "audio_accuracy_percent",
                "average_accuracy_percent",
                "visual_hits",
                "visual_misses",
                "visual_false_positives",
                "audio_hits",
                "audio_misses",
                "audio_false_positives",
            ].joined(separator: ",")
        )

        for session in sessions {
            let row: [String] = [
                Self.csvTimestampFormatter.string(from: session.completedAt),
                String(session.startN),
                String(session.endN),
                String(format: "%.2f", session.visualAccuracy),
                String(format: "%.2f", session.audioAccuracy),
                String(format: "%.2f", session.averageAccuracy),
                String(session.visualCounts.hits),
                String(session.visualCounts.misses),
                String(session.visualCounts.falsePositives),
                String(session.audioCounts.hits),
                String(session.audioCounts.misses),
                String(session.audioCounts.falsePositives),
            ]
            lines.append(row.map(csvEscaped).joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private func csvEscaped(_ value: String) -> String {
        let requiresEscaping = value.contains(",") || value.contains("\"") || value.contains("\n")
        guard requiresEscaping else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func defaultCSVFilename() -> String {
        guard
            let first = sortedSessions.first?.completedAt,
            let last = sortedSessions.last?.completedAt
        else {
            return "dual_n_back_score_history.csv"
        }

        let firstDate = Self.csvFilenameDateFormatter.string(from: first)
        let lastDate = Self.csvFilenameDateFormatter.string(from: last)
        return "dual_n_back_score_history_\(firstDate)_to_\(lastDate).csv"
    }
}
