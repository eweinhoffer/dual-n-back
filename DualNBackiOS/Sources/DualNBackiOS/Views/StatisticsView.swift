import Charts
import SwiftUI

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
    @State private var selectedChartTab: StatisticsChartTab = .rawScores
    @State private var csvShareURL: URL? = nil

    private static let csvTimestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let csvFilenameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(sessions: [SessionScore], onClearStatistics: @escaping () -> Void) {
        self.onClearStatistics = onClearStatistics
        self.sortedSessions = sessions.sorted { $0.completedAt < $1.completedAt }

        var points: [RawScoreChartPoint] = []
        points.reserveCapacity(self.sortedSessions.count * 2)
        for (index, session) in sortedSessions.enumerated() {
            let sessionIndex = index + 1
            points.append(.init(
                id: "\(session.id.uuidString)-V",
                sessionIndex: sessionIndex,
                accuracy: session.visualAccuracy,
                series: .visual
            ))
            points.append(.init(
                id: "\(session.id.uuidString)-A",
                sessionIndex: sessionIndex,
                accuracy: session.audioAccuracy,
                series: .audio
            ))
        }
        self.rawScoreChartPoints = points

        let calendar = Calendar.autoupdatingCurrent
        let sessionsByDay = Dictionary(grouping: self.sortedSessions) { session in
            calendar.startOfDay(for: session.completedAt)
        }
        self.dailyNLevelPoints = sessionsByDay.keys.sorted().enumerated().compactMap { offset, day in
            guard let daySessions = sessionsByDay[day], !daySessions.isEmpty else { return nil }
            let totalNLevel = daySessions.reduce(0.0) { $0 + Double($1.endN) }
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
            return "No sessions yet."
        }
        return "Last session: \(lastUpdatedAt.formatted(.dateTime.year().month().day().hour().minute()))"
    }

    var body: some View {
        NavigationStack {
            List {
                if !sortedSessions.isEmpty {
                    Section {
                        Picker("Chart", selection: $selectedChartTab) {
                            ForEach(StatisticsChartTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)

                        Group {
                            switch selectedChartTab {
                            case .rawScores: rawScoresChart
                            case .nLevel: nLevelChart
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }

                    Section("Session History") {
                        ForEach(sortedSessions.reversed()) { session in
                            SessionRowView(session: session)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Complete a run to create your first entry.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !sortedSessions.isEmpty {
                        if let shareURL = csvShareURL {
                            ShareLink(item: shareURL) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        } else {
                            Button {
                                csvShareURL = makeCSVFile()
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }

                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !sortedSessions.isEmpty {
                    Text(savedStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                }
            }
            .alert("Erase all score history?", isPresented: $showClearConfirmation) {
                Button("Erase", role: .destructive) { onClearStatistics() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes all saved session scores permanently.")
            }
        }
    }

    // MARK: - Charts

    private var rawScoresChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(rawScoreChartPoints) { point in
                    LineMark(
                        x: .value("Session", point.sessionIndex),
                        y: .value("Accuracy", point.accuracy),
                        series: .value("Stream", point.series.rawValue)
                    )
                    .foregroundStyle(by: .value("Stream", point.series.rawValue))

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
            .frame(height: 200)

            Text("Per-session visual and auditory accuracy.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var nLevelChart: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            .frame(height: 200)

            Text("Daily average N-level reached at end of each session.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var nLevelChartDomain: ClosedRange<Double> {
        guard
            let minValue = dailyNLevelPoints.map(\.averageNLevel).min(),
            let maxValue = dailyNLevelPoints.map(\.averageNLevel).max()
        else {
            return 1.0...2.0
        }
        let lower = max(1.0, floor((minValue - 0.5) * 2) / 2)
        let upper = max(lower + 1.0, ceil((maxValue + 0.5) * 2) / 2)
        return lower...upper
    }

    // MARK: - CSV Export

    private func makeCSVFile() -> URL? {
        let csv = makeCSVString()
        let fileName = defaultCSVFilename()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard (try? csv.write(to: url, atomically: true, encoding: .utf8)) != nil else {
            return nil
        }
        return url
    }

    private func makeCSVString() -> String {
        var lines = [
            "completed_at,start_n,end_n,visual_accuracy_percent,audio_accuracy_percent," +
            "average_accuracy_percent,visual_hits,visual_misses,visual_false_positives," +
            "audio_hits,audio_misses,audio_false_positives"
        ]
        for session in sortedSessions {
            let row = [
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
            ].joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n")
    }

    private func defaultCSVFilename() -> String {
        guard
            let first = sortedSessions.first?.completedAt,
            let last = sortedSessions.last?.completedAt
        else {
            return "dual_n_back_score_history.csv"
        }
        let f = Self.csvFilenameDateFormatter
        return "dual_n_back_score_history_\(f.string(from: first))_to_\(f.string(from: last)).csv"
    }
}

// MARK: - Session Row

private struct SessionRowView: View {
    let session: SessionScore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.completedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.subheadline)
                Spacer()
                Text("N \(session.startN)→\(session.endN)")
                    .font(.subheadline.bold())
                    .foregroundStyle(session.endN > session.startN ? .green : session.endN < session.startN ? .red : .primary)
            }
            HStack(spacing: 16) {
                Text(String(format: "Visual %.1f%%", session.visualAccuracy))
                Text(String(format: "Audio %.1f%%", session.audioAccuracy))
                Text(String(format: "Avg %.1f%%", session.averageAccuracy))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
