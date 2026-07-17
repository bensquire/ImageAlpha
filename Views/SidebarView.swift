import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: DocumentModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                Picker("Mode", selection: $model.quantizationMode) {
                    Text("Colors").tag(QuantizationMode.colors)
                    Text("Quality").tag(QuantizationMode.quality)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if model.quantizationMode == .colors {
                    headerRow(title: "Colors", value: model.colorsDisplayString)

                    HStack(spacing: 4) {
                        Slider(
                            value: $model.bitDepthSliderValue,
                            in: 1...9,
                            step: 1
                        )

                        Stepper("", value: $model.numberOfColors, in: 2...257)
                            .labelsHidden()
                    }
                } else {
                    headerRow(title: "Quality", value: "\(model.targetQuality)%")

                    Slider(value: targetQualityBinding, in: 0...100, step: 1)

                    Text("Palette: \(model.colorsDisplayString) colors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(model.sourceImage == nil)

            // Show original toggle
            Toggle("Show original", isOn: $model.showOriginal)
                .keyboardShortcut(.space, modifiers: [])
                .disabled(model.sourceImage == nil || model.compareMode)

            // Compare (split view) toggle
            Toggle("Compare", isOn: $model.compareMode)
                .disabled(model.sourceImage == nil)

            Divider()
                .padding(.vertical, 4)

            Text("Options")
                .font(.headline)

            // Dithered checkbox
            Toggle("Dithered", isOn: $model.dithering)
                .disabled(model.sourceImage == nil)

            Divider()
                .padding(.vertical, 4)

            Text("Backgrounds")
                .font(.headline)

            BackgroundGridView(model: model)

            Spacer()
        }
        .padding(12)
    }

    // Int model value ↔ Double slider value
    private var targetQualityBinding: Binding<Double> {
        Binding(
            get: { Double(model.targetQuality) },
            set: { model.targetQuality = Int($0.rounded()) }
        )
    }

    private func headerRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            }
        }
    }
}
