import AppKit
import Charts
import DualNBackCore
import SwiftUI
import UniformTypeIdentifiers

private enum StatisticsChartTab: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case lifetime = "Lifetime"

    var id: String { rawValue }
}

private struct WeeklyNLevelPoint: Identifiable {
    let weekIndex: Int
    let weekStart: Date
    let averageNLevel: Double
    let sessionCount: Int
    var id: Int { weekIndex }
}

private struct MonthlyNLevelPoint: Identifiable {
    let monthIndex: Int
    let monthStart: Date
    let averageNLevel: Double
    let sessionCount: Int

    var id: Int { monthIndex }
}

struct StatisticsView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @State private var exportStatusMessage = ""
    @State private var selectedChartTab: StatisticsChartTab = .weekly

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

    private var sortedSessions: [SessionScore] {
        game.statisticsHistory
    }

    private var weeklyNLevelPoints: [WeeklyNLevelPoint] {
        let calendar = Calendar.autoupdatingCurrent
        let sessionsByWeek = Dictionary(grouping: sortedSessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.completedAt)?.start
                ?? calendar.startOfDay(for: session.completedAt)
        }
        return sessionsByWeek.keys.sorted().enumerated().compactMap { offset, weekStart in
            guard let weekSessions = sessionsByWeek[weekStart], !weekSessions.isEmpty else { return nil }
            let total = weekSessions.reduce(0.0) { $0 + Double($1.endN) }
            return WeeklyNLevelPoint(
                weekIndex: offset + 1,
                weekStart: weekStart,
                averageNLevel: total / Double(weekSessions.count),
                sessionCount: weekSessions.count
            )
        }
    }

    private var monthlyNLevelPoints: [MonthlyNLevelPoint] {
        let calendar = Calendar.autoupdatingCurrent
        let sessionsByMonth = Dictionary(grouping: sortedSessions) { session in
            calendar.dateInterval(of: .month, for: session.completedAt)?.start
                ?? calendar.startOfDay(for: session.completedAt)
        }
        return sessionsByMonth.keys.sorted().enumerated().compactMap { offset, monthStart in
            guard let monthSessions = sessionsByMonth[monthStart], !monthSessions.isEmpty else { return nil }
            let total = monthSessions.reduce(0.0) { $0 + Double($1.endN) }
            return MonthlyNLevelPoint(
                monthIndex: offset + 1,
                monthStart: monthStart,
                averageNLevel: total / Double(monthSessions.count),
                sessionCount: monthSessions.count
            )
        }
    }

    private var savedStatusText: String {
        guard let lastUpdatedAt = sortedSessions.last?.completedAt else {
            return "Saved locally, no sessions yet."
        }
        return "Saved locally, last updated at \(lastUpdatedAt.formatted(.dateTime.year().month().day().hour().minute()))."
    }

    private var lifetimeAverageNLevel: Double {
        average(sortedSessions.map { Double($0.endN) })
    }

    private var lifetimeAverageAccuracy: Double {
        average(sortedSessions.map(\.averageAccuracy))
    }

    private var weeklyNLevelChartDomain: ClosedRange<Double> {
        guard
            let minValue = weeklyNLevelPoints.map(\.averageNLevel).min(),
            let maxValue = weeklyNLevelPoints.map(\.averageNLevel).max()
        else {
            return 1.0...2.0
        }
        let lower = max(1.0, floor((minValue - 0.5) * 2.0) / 2.0)
        let upper = max(lower + 1.0, ceil((maxValue + 0.5) * 2.0) / 2.0)
        return lower...upper
    }

    private var weeklyAxisMarks: [Int] {
        axisMarks(for: weeklyNLevelPoints.count)
    }

    private func weekLabel(for index: Int) -> String {
        guard let point = weeklyNLevelPoints.first(where: { $0.weekIndex == index }) else { return "" }
        return point.weekStart.formatted(.dateTime.month(.abbreviated).day())
    }

    private var monthlyNLevelChartDomain: ClosedRange<Double> {
        guard
            let minValue = monthlyNLevelPoints.map(\.averageNLevel).min(),
            let maxValue = monthlyNLevelPoints.map(\.averageNLevel).max()
        else {
            return 1.0...2.0
        }
        let lower = max(1.0, floor((minValue - 0.5) * 2.0) / 2.0)
        let upper = max(lower + 1.0, ceil((maxValue + 0.5) * 2.0) / 2.0)
        return lower...upper
    }

    private var monthlyAxisMarks: [Int] {
        axisMarks(for: monthlyNLevelPoints.count)
    }

    private func monthLabel(for index: Int) -> String {
        guard let point = monthlyNLevelPoints.first(where: { $0.monthIndex == index }) else { return "" }
        return point.monthStart.formatted(.dateTime.month(.abbreviated).year())
    }

    private func axisMarks(for pointCount: Int) -> [Int] {
        guard pointCount > 0 else { return [] }
        let desiredLabelCount = min(max(pointCount, 2), 7)
        let step = max(1, Int(ceil(Double(pointCount - 1) / Double(max(desiredLabelCount - 1, 1)))))
        var indices = Array(stride(from: 1, through: pointCount, by: step))
        if indices.last != pointCount { indices.append(pointCount) }
        return indices
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
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
                    case .weekly:
                        weeklyNLevelChart
                    case .monthly:
                        monthlyNLevelChart
                    case .lifetime:
                        lifetimeStatsView
                    }
                }

                List(sortedSessions.reversed()) { session in
                    HStack(spacing: 16) {
                        Text(session.completedAt, format: .dateTime.year().month().day().hour().minute())
                            .frame(minWidth: 180, alignment: .leading)
                        Text("N \(session.startN)->\(session.endN)")
                            .frame(minWidth: 70, alignment: .leading)
                            .foregroundStyle(
                                session.endN > session.startN ? Color.green :
                                session.endN < session.startN ? Color.red :
                                Color.primary
                            )
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

                Button("Copy Stats") {
                    copyStats()
                }
                .disabled(sortedSessions.isEmpty)

                Button("Paste Stats") {
                    pasteStats()
                }

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
                game.clearStatisticsHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes all saved session scores permanently.")
        }
    }

    private var weeklyNLevelChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(weeklyNLevelPoints) { point in
                    LineMark(
                        x: .value("Week", point.weekIndex),
                        y: .value("Average N-Level", point.averageNLevel)
                    )
                    .foregroundStyle(.purple)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Week", point.weekIndex),
                        y: .value("Average N-Level", point.averageNLevel)
                    )
                    .foregroundStyle(.purple)
                    .annotation(position: .top, alignment: .center) {
                        if point.sessionCount > 1 {
                            Text("\(point.sessionCount)x")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: weeklyNLevelChartDomain)
            .chartXAxis {
                AxisMarks(values: weeklyAxisMarks) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let index = value.as(Int.self) {
                            Text(weekLabel(for: index))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)

            Text("Weekly average N-level. Each point is the mean end-N across all sessions in that week.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(height: chartSectionHeight, alignment: .top)
    }

    private var monthlyNLevelChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(monthlyNLevelPoints) { point in
                    LineMark(
                        x: .value("Month", point.monthIndex),
                        y: .value("Average N-Level", point.averageNLevel)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Month", point.monthIndex),
                        y: .value("Average N-Level", point.averageNLevel)
                    )
                    .foregroundStyle(.blue)
                    .annotation(position: .top, alignment: .center) {
                        if point.sessionCount > 1 {
                            Text("\(point.sessionCount)x")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: monthlyNLevelChartDomain)
            .chartXAxis {
                AxisMarks(values: monthlyAxisMarks) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let index = value.as(Int.self) {
                            Text(monthLabel(for: index))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)

            Text("Monthly average N-level. Each point is the mean end-N across all sessions in that month.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(height: chartSectionHeight, alignment: .top)
    }

    private var lifetimeStatsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                lifetimeStatTile(title: "Games Played", value: "\(sortedSessions.count)")
                lifetimeStatTile(title: "Average N-Level", value: String(format: "%.1f", lifetimeAverageNLevel))
                lifetimeStatTile(title: "Average Accuracy", value: String(format: "%.1f%%", lifetimeAverageAccuracy))
            }

            Text("Lifetime totals across all saved sessions.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(height: chartSectionHeight, alignment: .center)
    }

    private func lifetimeStatTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func copyStats() {
        let count = game.copyStatsToClipboard()
        exportStatusMessage = count > 0
            ? "Copied \(count) sessions to clipboard."
            : "No sessions to copy."
    }

    private func pasteStats() {
        exportStatusMessage = "Checking clipboard…"
        let result = game.pasteStatsFromClipboard()
        switch result {
        case .success(let newCount, let duplicateCount):
            if newCount > 0 {
                exportStatusMessage = "Merged \(newCount) new sessions (\(duplicateCount) duplicates skipped)."
            } else {
                exportStatusMessage = "No new sessions found (\(duplicateCount) duplicates skipped)."
            }
        case .noData:
            exportStatusMessage = "Nothing on clipboard to paste."
        case .invalidFormat:
            exportStatusMessage = "Clipboard does not contain valid stats data."
        }
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
