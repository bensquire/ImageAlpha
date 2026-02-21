import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: DocumentModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Colors header row
            HStack {
                Text("Colors")
                    .font(.headline)
                Spacer()
                Text(model.colorsDisplayString)
                    .font(.system(.body, design: .monospaced))
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                }
            }

            // Slider + Stepper
            HStack(spacing: 4) {
                Slider(
                    value: $model.bitDepthSliderValue,
                    in: 1...9,
                    step: 1
                )
                .disabled(model.sourceImage == nil)

                Stepper("", value: $model.numberOfColors, in: 2...257)
                    .labelsHidden()
                    .disabled(model.sourceImage == nil)
            }

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

            // IE6-friendly checkbox
            Toggle("IE6-friendly alpha", isOn: $model.ieMode)
                .help("Forces nearly-opaque colors to be fully opaque. Makes most images degrade gracefully in IE6")
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
}
