import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var highlightRed: Double
    @Binding var highlightGreen: Double
    @Binding var highlightBlue: Double
    @Binding var showLiveStatusText: Bool
    @Binding var atAppOpenResumeLastLevel: Bool
    @Binding var atAppOpenStartLevel: Int

    private let presetColors: [(Color, Double, Double, Double)] = [
        (Color(red: 0.98, green: 0.62, blue: 0.33), 0.98, 0.62, 0.33), // warm peach
        (Color(red: 0.37, green: 0.70, blue: 0.94), 0.37, 0.70, 0.94), // soft sky
        (Color(red: 0.42, green: 0.78, blue: 0.61), 0.42, 0.78, 0.61), // mint
        (Color(red: 0.96, green: 0.78, blue: 0.42), 0.96, 0.78, 0.42), // honey
        (Color(red: 0.79, green: 0.64, blue: 0.96), 0.79, 0.64, 0.96), // lavender
        (Color(red: 0.95, green: 0.49, blue: 0.57), 0.95, 0.49, 0.57), // coral rose
    ]

    private var currentColor: Color {
        Color(red: highlightRed, green: highlightGreen, blue: highlightBlue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Toggle("Show live status text", isOn: $showLiveStatusText)
                    Text("Example: \"Trial 2/22 | N=2\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Startup Level") {
                    Toggle("Resume at last level", isOn: $atAppOpenResumeLastLevel)
                    Stepper("Start at level \(atAppOpenStartLevel)", value: $atAppOpenStartLevel, in: 1...8)
                        .disabled(atAppOpenResumeLastLevel)
                        .opacity(atAppOpenResumeLastLevel ? 0.5 : 1.0)
                }

                Section("Visual Stimulus Color") {
                    HStack(spacing: 12) {
                        ForEach(Array(presetColors.enumerated()), id: \.offset) { _, preset in
                            Button {
                                highlightRed = preset.1
                                highlightGreen = preset.2
                                highlightBlue = preset.3
                            } label: {
                                Circle()
                                    .fill(preset.0)
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().stroke(
                                            isCurrentColor(preset.0) ? Color.primary : Color.clear,
                                            lineWidth: 2
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    ColorPicker("Custom color", selection: Binding(
                        get: { currentColor },
                        set: { newColor in
                            let resolved = newColor.resolve(in: EnvironmentValues())
                            highlightRed = Double(resolved.red)
                            highlightGreen = Double(resolved.green)
                            highlightBlue = Double(resolved.blue)
                        }
                    ), supportsOpacity: false)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(currentColor)
                        .frame(height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func isCurrentColor(_ color: Color) -> Bool {
        let other = color.resolve(in: EnvironmentValues())
        return abs(Double(other.red) - highlightRed) < 0.01
            && abs(Double(other.green) - highlightGreen) < 0.01
            && abs(Double(other.blue) - highlightBlue) < 0.01
    }
}
