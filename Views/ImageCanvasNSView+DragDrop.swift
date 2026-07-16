import AppKit
import UniformTypeIdentifiers

// MARK: - Cursor & Drop Target

extension ImageCanvasNSView {

    /// Only accept file URLs whose content is an image, so the drag cursor
    /// doesn't promise a drop that would silently fail.
    private static let dropReadingOptions: [NSPasteboard.ReadingOptionKey: Any] = [
        .urlReadingFileURLsOnly: true,
        .urlReadingContentsConformToTypes: [UTType.image.identifier],
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
        if hasImageFileURLs(sender.draggingPasteboard) {
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
        return hasImageFileURLs(sender.draggingPasteboard)
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

    func hasImageFileURLs(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSURL.self], options: Self.dropReadingOptions)
    }
}
