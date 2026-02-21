import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How Dual N-Back Works")
                .font(.title.bold())
            Text("In each trial, one square in the 3x3 ring lights up and one spoken letter plays.")
            Text("Your task is to compare the current trial with the trial N steps earlier:")
            Text("• Press F for a visual match if the highlighted square is in the same position as N trials ago.")
            Text("• Press J for an auditory match if the spoken letter is the same as N trials ago.")
            Text("A trial can be visual-only, audio-only, both, or neither. Respond during the current 3-second cycle.")
            Text("Scoring uses hits, misses, and false positives. At the end of the session, the app adjusts N automatically based on your average accuracy.")
            Text("Session scores are saved locally. Open Statistics to review progress over time or erase saved history.")
            Text("Timing:")
            Text("• Stimulus visible for 0.5 seconds")
            Text("• Gap for 2.5 seconds")
            Text("• Total cycle length: 3.0 seconds")
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 420)
    }
}
