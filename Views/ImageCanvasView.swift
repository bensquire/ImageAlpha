import SwiftUI

struct ImageCanvasView: NSViewRepresentable {
    var model: DocumentModel
    var onDrop: (([URL], Bool) -> Void)?

    func makeNSView(context: Context) -> ImageCanvasNSView {
        let view = ImageCanvasNSView(frame: .zero)
        view.delegate = context.coordinator
        view.dragOutProvider = { [weak model] in
            guard let model, let data = model.quantizedPNGData else { return nil }
            return PromisedPNG(
                data: data,
                fileName: ImageCanvasNSView.dragOutFileName(for: model.sourceURL?.lastPathComponent))
        }
        view.zoomToFill()
        return view
    }

    func updateNSView(_ nsView: ImageCanvasNSView, context: Context) {
        let coordinator = context.coordinator

        if coordinator.lastBackground != model.selectedBackground {
            coordinator.lastBackground = model.selectedBackground
            nsView.checkerboardStyle = model.selectedBackground
        }

        if nsView.showOriginal != model.showOriginal {
            nsView.showOriginal = model.showOriginal
        }

        // Compare keeps the divider where the user left it.
        let wantSplit: CGFloat? = model.compareMode ? (nsView.splitPosition ?? 0.5) : nil
        if nsView.splitPosition != wantSplit {
            nsView.splitPosition = wantSplit
        }

        // In 24-bit passthrough quantizedImage is sourceImage itself, and it is
        // shown like any result; syncImageScale copying its own scale is a no-op.
        if !model.showOriginal,
            let qi = model.quantizedImage,
            nsView.displayImage !== qi
        {
            nsView.displayImage = qi
        }

        if coordinator.lastSourceImage !== model.sourceImage {
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
        let onDrop: (([URL], Bool) -> Void)?
        var lastBackground: BackgroundStyle?
        var lastSourceImage: NSImage?

        init(model: DocumentModel, onDrop: (([URL], Bool) -> Void)?) {
            self.model = model
            self.onDrop = onDrop
        }

        func canvasDidReceiveDrop(urls: [URL], areCopies: Bool) {
            onDrop?(urls, areCopies)
        }

        func canvasShowOriginalChanged(_ showOriginal: Bool) {
            Task { @MainActor in
                model.showOriginal = showOriginal
            }
        }
    }
}
