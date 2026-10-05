import AppKit
import UniformTypeIdentifiers

// MARK: - Cursor & Drop Target

extension ImageCanvasNSView {

    /// Only accept files the app opens as documents (its Info.plist types),
    /// so the drag cursor doesn't promise a drop that would fail, and an image
    /// it can't save back to never becomes a document.
    private static let dropReadingOptions: [NSPasteboard.ReadingOptionKey: Any] = [
        .urlReadingFileURLsOnly: true,
        .urlReadingContentsConformToTypes: ImageAlphaDocument.readableTypes,
    ]

    override func resetCursorRects() {
        // Add resize cursor over the split divider
        if let pos = splitPosition {
            let dividerX = bounds.width * pos
            let dividerRect = CGRect(x: dividerX - 8, y: 0, width: 16, height: bounds.height)
            addCursorRect(dividerRect, cursor: .resizeLeftRight)
        }

        if displayImage != nil || originalImage != nil || backgroundRenderer != nil {
            let cursor: NSCursor = mouseIsDown ? .closedHand : .openHand
            addCursorRect(visibleRect, cursor: cursor)
            cursor.set()
        }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if hasDocumentFileURLs(sender.draggingPasteboard) {
            imageFade = 0.15
            return [.copy]
        }
        return []
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        imageFade = 1.0
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        imageFade = 1.0
        return hasDocumentFileURLs(sender.draggingPasteboard)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: Self.dropReadingOptions
        ) as? [URL], !urls.isEmpty else {
            return false
        }
        delegate?.canvasDidReceiveDrop(urls: urls)
        return true
    }

    func hasDocumentFileURLs(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSURL.self], options: Self.dropReadingOptions)
    }
}

// MARK: - Drag Out

extension ImageCanvasNSView: NSDraggingSource, NSFilePromiseProviderDelegate {

    /// "To avoid blocking your main thread, provide an operation queue other
    /// than the main operation queue." /documentation/appkit/nsfilepromiseproviderdelegate/operationqueue(for:)
    private static let filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    // MARK: - NSFilePromiseProviderDelegate

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        fileNameForType fileType: String
    ) -> String {
        "ImageAlpha.png"
    }

    /// Writes the PNG captured when the drag began, since the result may have
    /// moved on by the time the drop lands, and reports a failure rather than
    /// success with no file.
    nonisolated func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        do {
            guard let data = filePromiseProvider.userInfo as? Data else {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSURLErrorKey: url])
            }
            try data.write(to: url)
            handler(nil)
        } catch {
            handler(error)
        }
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        Self.filePromiseQueue
    }

    func beginImageDrag(from event: NSEvent) {
        guard let data = pngDataProvider?() else { return }
        isDraggingOut = true

        let provider = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: self)
        provider.userInfo = data

        let draggingItem = NSDraggingItem(pasteboardWriter: provider)
        draggingItem.setDraggingFrame(imageLayer.frame, contents: displayImage ?? originalImage)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
}
