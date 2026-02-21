import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var visualHighlightColor: Color
    @Binding var showLiveStatusText: Bool
    @Binding var atAppOpenResumeLastLevel: Bool
    @Binding var atAppOpenStartLevel: Int

    private let presetColors: [Color] = [
        Color(red: 0.98, green: 0.62, blue: 0.33), // warm peach
        Color(red: 0.37, green: 0.70, blue: 0.94), // soft sky
        Color(red: 0.42, green: 0.78, blue: 0.61), // mint
        Color(red: 0.96, green: 0.78, blue: 0.42), // honey
        Color(red: 0.79, green: 0.64, blue: 0.96), // lavender
        Color(red: 0.95, green: 0.49, blue: 0.57), // coral rose
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Show live status text", isOn: $showLiveStatusText)
                Text("Example live status text: \"Trial 2/22 | N=2\"")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("At app open")
                    .font(.headline)
                Toggle("Resume at last level", isOn: $atAppOpenResumeLastLevel)
                Stepper("Start at level \(atAppOpenStartLevel)", value: $atAppOpenStartLevel, in: 1...8)
                    .disabled(atAppOpenResumeLastLevel)
                    .opacity(atAppOpenResumeLastLevel ? 0.5 : 1.0)
            }

            Text("Visual stimulus color")
                .font(.headline)
            Text("Quick presets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Array(presetColors.enumerated()), id: \.offset) { _, color in
                    Button {
                        visualHighlightColor = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            ColorPicker("Choose highlight color", selection: $visualHighlightColor, supportsOpacity: false)
            RoundedRectangle(cornerRadius: 10)
                .fill(visualHighlightColor)
                .frame(width: 120, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 320)
    }
}
