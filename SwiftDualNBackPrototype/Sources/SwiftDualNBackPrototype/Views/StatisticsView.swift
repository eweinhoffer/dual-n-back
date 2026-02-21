import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

private enum StreamSeries: String {
    case visual = "Visual"
    case audio = "Audio"
}

private struct ChartPoint: Identifiable {
    let id: String
    let time: Date
    let accuracy: Double
    let series: StreamSeries
}

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    let sessions: [SessionScore]
    let storageDescription: String
    let onClearStatistics: () -> Void
    @State private var showClearConfirmation = false
    @State private var exportStatusMessage = ""

    private var sortedSessions: [SessionScore] {
        sessions.sorted { $0.completedAt < $1.completedAt }
    }

    private var chartPoints: [ChartPoint] {
        var points: [ChartPoint] = []
        for session in sortedSessions {
            points.append(
                .init(
                    id: "\(session.id.uuidString)-\(StreamSeries.visual.rawValue)",
                    time: session.completedAt,
                    accuracy: session.visualAccuracy,
                    series: .visual
                )
            )
            points.append(
                .init(
                    id: "\(session.id.uuidString)-\(StreamSeries.audio.rawValue)",
                    time: session.completedAt,
                    accuracy: session.audioAccuracy,
                    series: .audio
                )
            )
        }
        return points
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Statistics")
                .font(.title.bold())

            Text(storageDescription)
                .font(.callout)
                .foregroundStyle(.secondary)

            if sortedSessions.isEmpty {
                Text("No saved sessions yet. Complete a run to create your first entry.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                Chart {
                    ForEach(chartPoints) { point in
                        LineMark(
                            x: .value("Time", point.time),
                            y: .value("Accuracy", point.accuracy),
                            series: .value("Stream", point.series.rawValue)
                        )
                        .foregroundStyle(by: .value("Stream", point.series.rawValue))
                    }

                    ForEach(chartPoints) { point in
                        PointMark(
                            x: .value("Time", point.time),
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
                .frame(height: 220)

                HStack(spacing: 20) {
                    Label("Visual Accuracy", systemImage: "circle.fill")
                        .foregroundStyle(.blue)
                    Label("Audio Accuracy", systemImage: "circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.callout)

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
                .frame(minHeight: 240)
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
        .frame(minWidth: 780, minHeight: 560)
        .alert("Erase all score history?", isPresented: $showClearConfirmation) {
            Button("Erase", role: .destructive) {
                onClearStatistics()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes all saved session scores permanently.")
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
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

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
                isoFormatter.string(from: session.completedAt),
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

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let firstDate = formatter.string(from: first)
        let lastDate = formatter.string(from: last)
        return "dual_n_back_score_history_\(firstDate)_to_\(lastDate).csv"
    }
}
