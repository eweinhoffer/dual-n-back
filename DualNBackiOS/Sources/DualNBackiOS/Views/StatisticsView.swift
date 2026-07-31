import Charts
import DualNBackCore
import SwiftUI

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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var game: GameEngine
    @State private var showClearConfirmation = false
    @State private var showSyncOptions = false
    @State private var selectedChartTab: StatisticsChartTab = .weekly
    @State private var csvShareURL: URL? = nil
    @State private var clipboardStatusMessage = ""
    @State private var selectedWeeklyIndex: Int? = nil
    @State private var selectedMonthlyIndex: Int? = nil

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

    private static let monthAxisFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "MMM yy"
        return f
    }()

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
            return "No sessions yet."
        }
        return "Last session: \(lastUpdatedAt.formatted(.dateTime.year().month().day().hour().minute()))"
    }

    private var lifetimeAverageNLevel: Double {
        average(sortedSessions.map { Double($0.endN) })
    }

    private var lifetimeAverageAccuracy: Double {
        average(sortedSessions.map(\.averageAccuracy))
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
                            case .weekly: weeklyNLevelChart
                            case .monthly: monthlyNLevelChart
                            case .lifetime: lifetimeStatsView
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }

                    Section("Session History") {
                        ForEach(sortedSessions.reversed()) { session in
                            SessionRowView(session: session)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No Sessions Yet")
                            .font(.title3.bold())
                        Text("Complete a run to create your first entry.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
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
                    Button {
                        showSyncOptions = true
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }

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
                VStack(spacing: 4) {
                    if !clipboardStatusMessage.isEmpty {
                        Text(clipboardStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !sortedSessions.isEmpty {
                        Text(savedStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
            .alert("Erase all score history?", isPresented: $showClearConfirmation) {
                Button("Erase", role: .destructive) { game.clearStatisticsHistory() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes all saved session scores permanently.")
            }
            .fullScreenCover(isPresented: $showSyncOptions) {
                syncOptionsView
            }
        }
    }

    // MARK: - Charts

    private var weeklyNLevelChart: some View {
        let pointCount = weeklyNLevelPoints.count
        let chartWidth = max(280, CGFloat(pointCount) * 52)
        return VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
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
                        .symbolSize(point.weekIndex == selectedWeeklyIndex ? 120 : 50)
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
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        let origin = geo[proxy.plotAreaFrame].origin
                                        let x = value.location.x - origin.x
                                        if let index = proxy.value(atX: x, as: Int.self) {
                                            let clamped = min(max(index, 1), weeklyNLevelPoints.count)
                                            selectedWeeklyIndex = selectedWeeklyIndex == clamped ? nil : clamped
                                        }
                                    }
                            )
                    }
                }
                .frame(width: chartWidth, height: 200)
            }

            if let idx = selectedWeeklyIndex,
               let point = weeklyNLevelPoints.first(where: { $0.weekIndex == idx }) {
                let sessionNote = point.sessionCount > 1 ? " (\(point.sessionCount) sessions)" : ""
                Text("Week of \(point.weekStart.formatted(.dateTime.month(.abbreviated).day().year())) · Avg N \(String(format: "%.1f", point.averageNLevel))\(sessionNote)")
                    .font(.caption)
                    .foregroundStyle(.primary)
            } else {
                Text("Tap a point to see the week.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var monthlyNLevelChart: some View {
        let pointCount = monthlyNLevelPoints.count
        return GeometryReader { geometry in
            let chartWidth = max(geometry.size.width, CGFloat(max(pointCount, 1)) * 72)

            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
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
                            .symbolSize(point.monthIndex == selectedMonthlyIndex ? 120 : 50)
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
                                    Text(monthAxisLabel(for: index))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    SpatialTapGesture()
                                        .onEnded { value in
                                            let origin = geo[proxy.plotAreaFrame].origin
                                            let x = value.location.x - origin.x
                                            if let index = proxy.value(atX: x, as: Int.self) {
                                                let clamped = min(max(index, 1), monthlyNLevelPoints.count)
                                                selectedMonthlyIndex = selectedMonthlyIndex == clamped ? nil : clamped
                                            }
                                        }
                                )
                        }
                    }
                    .frame(width: chartWidth, height: 215)
                }

                if let idx = selectedMonthlyIndex,
                   let point = monthlyNLevelPoints.first(where: { $0.monthIndex == idx }) {
                    let sessionNote = point.sessionCount > 1 ? " (\(point.sessionCount) sessions)" : ""
                    Text("\(point.monthStart.formatted(.dateTime.month(.wide).year())) · Avg N \(String(format: "%.1f", point.averageNLevel))\(sessionNote)")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text("Tap a point to see the month.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 245)
    }

    private var lifetimeStatsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                lifetimeStatTile(title: "Games", value: "\(sortedSessions.count)")
                lifetimeStatTile(title: "Avg N", value: String(format: "%.1f", lifetimeAverageNLevel))
            }
            lifetimeStatTile(title: "Avg Accuracy", value: String(format: "%.1f%%", lifetimeAverageAccuracy))
        }
        .padding(.vertical, 4)
    }

    private func lifetimeStatTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var weeklyNLevelChartDomain: ClosedRange<Double> {
        nLevelChartDomain(for: weeklyNLevelPoints.map(\.averageNLevel))
    }

    private var monthlyNLevelChartDomain: ClosedRange<Double> {
        nLevelChartDomain(for: monthlyNLevelPoints.map(\.averageNLevel))
    }

    private var monthlyAxisMarks: [Int] {
        axisMarks(for: monthlyNLevelPoints.count, maximumLabels: 6)
    }

    private func monthAxisLabel(for index: Int) -> String {
        guard let point = monthlyNLevelPoints.first(where: { $0.monthIndex == index }) else { return "" }
        return Self.monthAxisFormatter.string(from: point.monthStart)
    }

    private func nLevelChartDomain(for values: [Double]) -> ClosedRange<Double> {
        guard let minValue = values.min(), let maxValue = values.max() else { return 1.0...2.0 }
        let lower = max(1.0, floor((minValue - 0.5) * 2) / 2)
        let upper = max(lower + 1.0, ceil((maxValue + 0.75) * 2) / 2)
        return lower...upper
    }

    private func axisMarks(for pointCount: Int, maximumLabels: Int) -> [Int] {
        guard pointCount > 0 else { return [] }
        let desiredLabelCount = min(pointCount, maximumLabels)
        let step = max(1, Int(ceil(Double(pointCount - 1) / Double(max(desiredLabelCount - 1, 1)))))
        var indices = Array(stride(from: 1, through: pointCount, by: step))
        if indices.last != pointCount { indices.append(pointCount) }
        return indices
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Sync Options

    private var syncOptionsView: some View {
        NavigationStack {
            VStack(spacing: 12) {
                syncActionButton(
                    title: "Copy Stats",
                    systemImage: "doc.on.doc",
                    isDisabled: sortedSessions.isEmpty
                ) {
                    copyStats()
                    showSyncOptions = false
                }

                syncActionButton(title: "Paste Stats", systemImage: "doc.on.clipboard") {
                    pasteStats()
                    showSyncOptions = false
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .navigationTitle("Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showSyncOptions = false }
                }
            }
        }
    }

    private func syncActionButton(
        title: String,
        systemImage: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 28)
                Text(title)
                    .font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }

    // MARK: - Clipboard Transfer

    private func copyStats() {
        let count = game.copyStatsToClipboard()
        clipboardStatusMessage = count > 0
            ? "Copied \(count) sessions to clipboard."
            : "No sessions to copy."
    }

    private func pasteStats() {
        clipboardStatusMessage = "Checking clipboard…"
        let result = game.pasteStatsFromClipboard()
        switch result {
        case .success(let newCount, let duplicateCount):
            if newCount > 0 {
                clipboardStatusMessage = "Merged \(newCount) new sessions (\(duplicateCount) duplicates skipped)."
            } else {
                clipboardStatusMessage = "No new sessions found (\(duplicateCount) duplicates skipped)."
            }
        case .noData:
            clipboardStatusMessage = "Nothing on clipboard to paste."
        case .invalidFormat:
            clipboardStatusMessage = "Clipboard does not contain valid stats data."
        }
    }

    // MARK: - CSV Export

    private func makeCSVFile() -> URL? {
        let csv = makeCSVString()
        let fileName = defaultCSVFilename()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DualNBackExports-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent(fileName)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try csv.write(to: url, atomically: true, encoding: .utf8)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            #endif
        } catch {
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
