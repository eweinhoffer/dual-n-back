import DualNBackCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: GameEngine
    @Environment(\.openWindow) private var openWindow
    @State private var showHelp = false
    @State private var showSettings = false
    @AppStorage("showLiveStatusText") private var showLiveStatusText = true
    @AppStorage("atAppOpenResumeLastLevel") private var atAppOpenResumeLastLevel = true
    @AppStorage("atAppOpenStartLevel") private var atAppOpenStartLevel = 2
    @AppStorage("lastKnownNLevel") private var lastKnownNLevel = 2
    @AppStorage("randomColorEnabled") private var randomColorEnabled = false
    @State private var visualHighlightColor: Color = .orange
    @State private var appliedStartupLevel = false

    private let presetColors: [Color] = [
        Color(red: 0.98, green: 0.62, blue: 0.33),
        Color(red: 0.37, green: 0.70, blue: 0.94),
        Color(red: 0.42, green: 0.78, blue: 0.61),
        Color(red: 0.96, green: 0.78, blue: 0.42),
        Color(red: 0.79, green: 0.64, blue: 0.96),
        Color(red: 0.95, green: 0.49, blue: 0.57),
    ]

    var body: some View {
        VStack(spacing: 14) {
            Text("Dual N-Back")
                .font(.title2.bold())

            HStack(spacing: 18) {
                Stepper("N: \(game.nLevel)", value: $game.nLevel, in: GameLimits.nLevelRange)
                    .focusable(false)
                Text("Trials this session: \(game.totalTrials)")
                    .font(.callout)
                Button("Help") {
                    showHelp = true
                }
                .focusable(false)
                Button("Settings") {
                    showSettings = true
                }
                .focusable(false)
                Button("Statistics") {
                    openWindow(id: "statistics")
                }
                .focusable(false)
            }

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
            .overlay {
                if let value = game.countdownValue {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.black.opacity(0.5))
                        Text("\(value)")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }

            HStack(spacing: 12) {
                Button(game.isRunning || game.isPreparingStart ? "Running" : "Start") {
                    if randomColorEnabled, let pick = presetColors.randomElement() {
                        visualHighlightColor = pick
                    }
                    game.start()
                }
                .disabled(game.isRunning || game.isPreparingStart)
                .focusable(false)

                Button("Stop") {
                    game.stop()
                }
                .disabled(!game.isRunning && !game.isPreparingStart)
                .focusable(false)
            }

            HStack(spacing: 12) {
                Button {
                    game.registerPositionAction()
                } label: {
                    Label("Visual Match (F)", systemImage: "square.grid.3x3.fill")
                        .frame(minWidth: 170)
                }
                .buttonStyle(.borderedProminent)
                .tint(game.visualButtonActive ? .orange : .accentColor)
                .disabled(!game.buttonsAvailable)
                .focusable(false)

                Button {
                    game.registerAudioAction()
                } label: {
                    Label("Auditory Match (J)", systemImage: "speaker.wave.2.fill")
                        .frame(minWidth: 170)
                }
                .buttonStyle(.borderedProminent)
                .tint(game.audioButtonActive ? .orange : .accentColor)
                .disabled(!game.buttonsAvailable)
                .focusable(false)
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
        .frame(minWidth: 460, idealWidth: 620, minHeight: 560, idealHeight: 760)
        .background(
            KeyCaptureView(
                onF: { game.registerPositionAction() },
                onJ: { game.registerAudioAction() },
                onEnter: {
                    guard game.showResultPopup else { return }
                    game.showResultPopup = false
                }
            )
        )
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                visualHighlightColor: $visualHighlightColor,
                randomColorEnabled: $randomColorEnabled,
                showLiveStatusText: $showLiveStatusText,
                atAppOpenResumeLastLevel: $atAppOpenResumeLastLevel,
                atAppOpenStartLevel: $atAppOpenStartLevel
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
                .keyboardShortcut(.defaultAction)
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
        GameLimits.clampedNLevel(value)
    }
}
