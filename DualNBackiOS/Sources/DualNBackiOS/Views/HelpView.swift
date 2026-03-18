import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    helpSection(
                        title: "How It Works",
                        items: [
                            "In each trial, one square in the 3×3 ring lights up and one spoken letter plays.",
                            "Your task is to compare the current trial with the trial N steps earlier.",
                        ]
                    )

                    helpSection(
                        title: "What to Do",
                        items: [
                            "Tap Visual Match if the highlighted square is in the same position as N trials ago.",
                            "Tap Auditory Match if the spoken letter is the same as N trials ago.",
                            "A trial can be visual-only, audio-only, both, or neither.",
                            "Respond any time during the current 3-second cycle.",
                        ]
                    )

                    helpSection(
                        title: "Scoring & Difficulty",
                        items: [
                            "Scoring uses hits, misses, and false positives.",
                            "At session end the app adjusts N automatically: ≥90% average → N up, <75% → N down.",
                            "Session scores are saved locally. Open Statistics to review your progress.",
                        ]
                    )

                    helpSection(
                        title: "Timing",
                        items: [
                            "Stimulus visible: 0.5 seconds",
                            "Gap: 2.5 seconds",
                            "Total cycle: 3.0 seconds",
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func helpSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                Label {
                    Text(item)
                        .font(.body)
                } icon: {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
}
