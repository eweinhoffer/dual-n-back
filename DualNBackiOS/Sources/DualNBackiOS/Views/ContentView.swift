import DualNBackCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: GameEngine
    @State private var showHelp = false
    @State private var showSettings = false
    @State private var showStatistics = false
    @AppStorage("showLiveStatusText") private var showLiveStatusText = true
    @AppStorage("atAppOpenResumeLastLevel") private var atAppOpenResumeLastLevel = true
    @AppStorage("atAppOpenStartLevel") private var atAppOpenStartLevel = 2
    @AppStorage("highlightColorRed") private var highlightRed = 0.98
    @AppStorage("highlightColorGreen") private var highlightGreen = 0.62
    @AppStorage("highlightColorBlue") private var highlightBlue = 0.33
    @State private var appliedStartupLevel = false

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    private var highlightColor: Color {
        Color(red: highlightRed, green: highlightGreen, blue: highlightBlue)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                nLevelRow

                GameGridView(
                    currentDisplayIndex: game.currentDisplayIndex,
                    highlightColor: highlightColor
                )
                .padding(.horizontal, 8)

                controlRow

                matchButtons

                if showLiveStatusText && !game.statusText.isEmpty {
                    Text(game.statusText)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if game.didCompleteSession && !game.isRunning && !game.isPreparingStart {
                    scoreBreakdown
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Stats") { showStatistics = true }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Help") { showHelp = true }
                Button("Settings") { showSettings = true }
            }
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                highlightRed: $highlightRed,
                highlightGreen: $highlightGreen,
                highlightBlue: $highlightBlue,
                showLiveStatusText: $showLiveStatusText,
                atAppOpenResumeLastLevel: $atAppOpenResumeLastLevel,
                atAppOpenStartLevel: $atAppOpenStartLevel
            )
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView(
                sessions: game.statisticsHistory,
                onClearStatistics: { game.clearStatisticsHistory() },
                onCopyStats: { game.copyStatsToClipboard() },
                onPasteStats: { game.pasteStatsFromClipboard() }
            )
        }
        .sheet(isPresented: $game.showResultPopup) {
            resultPopup
        }
        .onAppear {
            applyStartupLevelIfNeeded()
            haptic.prepare()
        }
    }

    // MARK: - Subviews

    private var nLevelRow: some View {
        HStack {
            Text("Trials: \(game.totalTrials)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Stepper("N: \(game.nLevel)", value: $game.nLevel, in: 1...8)
                .fixedSize()
                .disabled(game.isRunning || game.isPreparingStart)
        }
        .padding(.horizontal)
    }

    private var controlRow: some View {
        HStack(spacing: 16) {
            Button {
                game.start()
            } label: {
                Text(game.isRunning || game.isPreparingStart ? "Running…" : "Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(game.isRunning || game.isPreparingStart)

            Button {
                game.stop()
            } label: {
                Text("Stop")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!game.isRunning && !game.isPreparingStart)
        }
        .padding(.horizontal)
    }

    private var matchButtons: some View {
        HStack(spacing: 12) {
            Button {
                haptic.impactOccurred()
                game.registerPositionAction()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.title2)
                    Text("Visual Match")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(game.visualButtonActive ? .orange : .accentColor)
            .disabled(!game.isRunning)

            Button {
                haptic.impactOccurred()
                game.registerAudioAction()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                    Text("Auditory Match")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(game.audioButtonActive ? .orange : .accentColor)
            .disabled(!game.isRunning)
        }
        .padding(.horizontal)
    }

    private var scoreBreakdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Visual  TP:\(game.posHits)  Miss:\(game.posMisses)  FP:\(game.posFalse)")
            Text("Audio   TP:\(game.audHits)  Miss:\(game.audMisses)  FP:\(game.audFalse)")
        }
        .font(.system(.footnote, design: .monospaced))
        .padding(.horizontal)
    }

    private var resultPopup: some View {
        VStack(spacing: 24) {
            Text("Session Complete")
                .font(.title.bold())
            Text(game.resultSummaryText)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Close") {
                game.showResultPopup = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func applyStartupLevelIfNeeded() {
        guard !appliedStartupLevel else { return }
        appliedStartupLevel = true
        if atAppOpenResumeLastLevel {
            // Derive from the most recent session's end N-level so clipboard sync is reflected.
            // Falls back to the default (2) if no sessions exist.
            if let lastSession = game.statisticsHistory.last {
                game.nLevel = clampLevel(lastSession.endN)
            }
        } else {
            game.nLevel = clampLevel(atAppOpenStartLevel)
        }
    }

    private func clampLevel(_ value: Int) -> Int {
        min(max(value, 1), 8)
    }
}
