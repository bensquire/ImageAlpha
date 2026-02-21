import SwiftUI

struct ImageCanvasView: NSViewRepresentable {
    @ObservedObject var model: DocumentModel
    var onDrop: (([URL]) -> Void)?

    func makeNSView(context: Context) -> ImageCanvasNSView {
        let view = ImageCanvasNSView(frame: .zero)
        view.delegate = context.coordinator
        view.pngDataProvider = { [weak model] in model?.quantizedPNGData }
        view.zoomToFill()
        return view
    }

    func updateNSView(_ nsView: ImageCanvasNSView, context: Context) {
        let coordinator = context.coordinator

        // Update background if changed
        if coordinator.lastBackground != model.selectedBackground {
            coordinator.lastBackground = model.selectedBackground
            nsView.checkerboardStyle = model.selectedBackground
        }

        // Update show original state
        if nsView.showOriginal != model.showOriginal {
            nsView.showOriginal = model.showOriginal
        }

        // Update compare (split) mode
        let wantSplit: CGFloat? = model.compareMode ? (nsView.splitPosition ?? 0.5) : nil
        if (nsView.splitPosition == nil) != (wantSplit == nil) || nsView.splitPosition != wantSplit {
            nsView.splitPosition = wantSplit
        }

        // Update display image (skip if quantizedImage is the same object as sourceImage,
        // e.g. when numberOfColors > 256 — avoids scale/size conflicts)
        if !model.showOriginal,
           let qi = model.quantizedImage,
           qi !== model.sourceImage,
           nsView.displayImage !== qi {
            nsView.displayImage = qi
        }

        // Update original image
        if coordinator.lastSourceImage !== model.sourceImage {
            NSLog("updateNSView: setting originalImage=%@", model.sourceImage?.description ?? "nil")
            coordinator.lastSourceImage = model.sourceImage
            nsView.originalImage = model.sourceImage
            if model.sourceImage != nil {
                nsView.zoomToFill()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model, onDrop: onDrop)
    }

    class Coordinator: NSObject, ImageCanvasDelegate {
        let model: DocumentModel
        let onDrop: (([URL]) -> Void)?
        var lastBackground: BackgroundStyle?
        var lastSourceImage: NSImage?

        init(model: DocumentModel, onDrop: (([URL]) -> Void)?) {
            self.model = model
            self.onDrop = onDrop
        }

        func canvasDidReceiveDrop(urls: [URL]) {
            onDrop?(urls)
        }

        func canvasShowOriginalChanged(_ showOriginal: Bool) {
            Task { @MainActor in
                model.showOriginal = showOriginal
            }
        }
    }
}
