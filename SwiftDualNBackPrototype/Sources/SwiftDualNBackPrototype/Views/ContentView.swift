import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameEngine()
    @State private var showHelp = false
    @State private var showSettings = false
    @State private var showStatistics = false
    @AppStorage("showLiveStatusText") private var showLiveStatusText = true
    @AppStorage("atAppOpenResumeLastLevel") private var atAppOpenResumeLastLevel = true
    @AppStorage("atAppOpenStartLevel") private var atAppOpenStartLevel = 2
    @AppStorage("lastKnownNLevel") private var lastKnownNLevel = 2
    @State private var visualHighlightColor: Color = .orange
    @State private var appliedStartupLevel = false

    var body: some View {
        VStack(spacing: 14) {
            Text("Dual N-Back (Swift)")
                .font(.title2.bold())

            Text("F = visual match | J = auditory-letter match")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                Stepper("N: \(game.nLevel)", value: $game.nLevel, in: 1...8)
                Text("Trials this session: \(game.totalTrials)")
                    .font(.callout)
                Button("Help") {
                    showHelp = true
                }
                Button("Settings") {
                    showSettings = true
                }
                Button("Statistics") {
                    showStatistics = true
                }
            }

            Text("Saved sessions: \(game.statisticsHistory.count)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Timing is fixed: 500ms stimulus + 2500ms gap (3s total pacing)")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { col in
                            let displayIdx = row * 3 + col
                            if displayIdx == 4 {
                                Color.clear
                                    .frame(width: 96, height: 96)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(game.currentDisplayIndex == displayIdx ? visualHighlightColor : Color.gray.opacity(0.28))
                                    .frame(width: 96, height: 96)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.6), lineWidth: 1.2)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 6)

            HStack(spacing: 12) {
                Button(game.isRunning || game.isPreparingStart ? "Running" : "Start") {
                    game.start()
                }
                .disabled(game.isRunning || game.isPreparingStart)

                Button("Stop") {
                    game.stop()
                }
                .disabled(!game.isRunning && !game.isPreparingStart)
            }

            HStack(spacing: 12) {
                Button {
                    game.registerPositionAction()
                } label: {
                    Label("Visual Match (F)", systemImage: "square.grid.3x3.fill")
                        .frame(minWidth: 190)
                }
                .buttonStyle(.borderedProminent)
                .tint(game.visualButtonActive ? .orange : .accentColor)
                .disabled(!game.isRunning)

                Button {
                    game.registerAudioAction()
                } label: {
                    Label("Auditory Match (J)", systemImage: "speaker.wave.2.fill")
                        .frame(minWidth: 190)
                }
                .buttonStyle(.borderedProminent)
                .tint(game.audioButtonActive ? .orange : .accentColor)
                .disabled(!game.isRunning)
            }

            if showLiveStatusText && !game.statusText.isEmpty {
                Text(game.statusText)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
            }

            if game.didCompleteSession && !game.isRunning && !game.isPreparingStart {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Visual TP:\(game.posHits)  Miss:\(game.posMisses)  FP:\(game.posFalse)")
                    Text("Audio  TP:\(game.audHits)  Miss:\(game.audMisses)  FP:\(game.audFalse)")
                }
                .font(.system(.body, design: .monospaced))
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(idealWidth: 760, idealHeight: 760)
        .background(
            KeyCaptureView(
                onF: { game.registerPositionAction() },
                onJ: { game.registerAudioAction() }
            )
        )
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                visualHighlightColor: $visualHighlightColor,
                showLiveStatusText: $showLiveStatusText,
                atAppOpenResumeLastLevel: $atAppOpenResumeLastLevel,
                atAppOpenStartLevel: $atAppOpenStartLevel
            )
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView(
                sessions: game.statisticsHistory,
                storageDescription: game.statisticsStorageDescription,
                onClearStatistics: { game.clearStatisticsHistory() }
            )
        }
        .sheet(isPresented: $game.showResultPopup) {
            VStack(spacing: 18) {
                Text("Session Complete")
                    .font(.system(size: 36, weight: .bold))
                Text(game.resultSummaryText)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                Button("Close") {
                    game.showResultPopup = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .frame(minWidth: 640, minHeight: 320)
        }
        .onAppear {
            applyStartupLevelIfNeeded()
        }
        .onChange(of: game.nLevel) { newValue in
            lastKnownNLevel = clampLevel(newValue)
        }
    }

    private func applyStartupLevelIfNeeded() {
        guard !appliedStartupLevel else { return }
        appliedStartupLevel = true
        let startupLevel = atAppOpenResumeLastLevel ? lastKnownNLevel : atAppOpenStartLevel
        game.nLevel = clampLevel(startupLevel)
    }

    private func clampLevel(_ value: Int) -> Int {
        min(max(value, 1), 8)
    }
}
