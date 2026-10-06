import AppKit
import UniformTypeIdentifiers

// MARK: - Cursor

extension ImageCanvasNSView {

    var hasImage: Bool { displayImage != nil || originalImage != nil }

    /// Within grabbing distance of the compare divider, where a click drags it.
    func isOnDivider(_ point: NSPoint) -> Bool {
        guard let pos = splitPosition else { return false }
        return abs(point.x - bounds.width * pos) < 8
    }

    /// The resize arrows over the compare divider, else a hand over anything
    /// that can be dragged.
    func cursor(at point: NSPoint) -> NSCursor {
        if isOnDivider(point) {
            return .resizeLeftRight
        }
        if hasImage || backgroundRenderer != nil {
            return mouseIsDown ? .closedHand : .openHand
        }
        return .arrow
    }

    /// The tracking area asks for cursor updates, "to set the cursor image",
    /// and for mouse moves, since the cursor changes within the view.
    /// /documentation/appkit/nsresponder/cursorupdate(with:)
    override func cursorUpdate(with event: NSEvent) {
        cursor(at: convert(event.locationInWindow, from: nil)).set()
    }

    override func mouseMoved(with event: NSEvent) {
        cursorUpdate(with: event)
    }

    /// Sets the cursor after a change of state, if the pointer is over the view.
    func refreshCursor() {
        guard let window else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if bounds.contains(point) {
            cursor(at: point).set()
        }
    }
}

// MARK: - Drop Target

extension ImageCanvasNSView {

    /// Only accept files the app opens as documents (its Info.plist types),
    /// so the drag cursor doesn't promise a drop that would fail, and an image
    /// it can't save back to never becomes a document.
    private static let dropReadingOptions: [NSPasteboard.ReadingOptionKey: Any] = [
        .urlReadingFileURLsOnly: true,
        .urlReadingContentsConformToTypes: ImageAlphaDocument.readableTypes,
    ]
    private static let readableTypes = ImageAlphaDocument.readableTypes.compactMap { UTType($0) }

    /// A copy, if the source permits one and the files are ones the canvas
    /// opens. The canvas's own drag out permits nothing inside the app, so an
    /// image dragged and let go over itself isn't reopened as a copy.
    /// /documentation/appkit/nsdragginginfo/draggingsourceoperationmask
    func dropOperation(for pasteboard: NSPasteboard, sourceMask: NSDragOperation) -> NSDragOperation {
        sourceMask.contains(.copy) && canOpenDrop(from: pasteboard) ? .copy : []
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let operation = dropOperation(for: sender.draggingPasteboard, sourceMask: sender.draggingSourceOperationMask)
        if !operation.isEmpty {
            imageFade = 0.15
        }
        return operation
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        imageFade = 1.0
    }

    /// "invoked only if the most recent draggingEntered(_:) … returned an
    /// acceptable drag-operation value", so there's nothing left to check.
    /// /documentation/appkit/nsdraggingdestination/preparefordragoperation(_:)
    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        imageFade = 1.0
        return true
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: Self.dropReadingOptions) as? [URL],
            !urls.isEmpty
        {
            delegate?.canvasDidReceiveDrop(urls: urls, areCopies: false)
            return true
        }
        return receivePromisedFiles(from: pasteboard)
    }

    /// Files on disk, or files promised by apps such as Photos, Mail and
    /// browsers, of a type the app opens.
    private func canOpenDrop(from pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSURL.self], options: Self.dropReadingOptions)
            || !documentPromises(on: pasteboard).isEmpty
    }

    private func documentPromises(on pasteboard: NSPasteboard) -> [NSFilePromiseReceiver] {
        let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
        return receivers.filter { receiver in
            receiver.fileTypes.contains { type in
                guard let promised = UTType(type) ?? UTType(filenameExtension: type) else { return false }
                return Self.readableTypes.contains { promised.conforms(to: $0) }
            }
        }
    }

    /// A promised file has nowhere to live until it's written, so it's
    /// received into a fresh temporary folder and opened from there. Written
    /// off the main thread: "Avoid blocking the main thread while waiting for
    /// the file promise to be written".
    /// /documentation/appkit/nsfilepromisereceiver/receivepromisedfiles(atdestination:options:operationqueue:reader:)
    private func receivePromisedFiles(from pasteboard: NSPasteboard) -> Bool {
        let promises = documentPromises(on: pasteboard)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("Drops", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        guard !promises.isEmpty,
            (try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)) != nil
        else { return false }
        for promise in promises {
            // Weak from the outset: the receiver keeps this block until the
            // file arrives, which a slow source can put off indefinitely.
            promise.receivePromisedFiles(
                atDestination: destination, options: [:], operationQueue: Self.filePromiseQueue
            ) { [weak self] url, error in
                DispatchQueue.main.async {
                    if let error {
                        self?.presentError(error)
                    } else {
                        self?.delegate?.canvasDidReceiveDrop(urls: [url], areCopies: true)
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Drag Out

/// What a drag-out carries: the PNG as it was when the drag began, and the
/// name to give it.
struct PromisedPNG {
    let data: Data
    let fileName: String
}

extension ImageCanvasNSView: NSDraggingSource, NSFilePromiseProviderDelegate {

    /// Where promised files are written and received, off the main thread:
    /// "To avoid blocking your main thread, provide an operation queue other
    /// than the main operation queue." /documentation/appkit/nsfilepromiseproviderdelegate/operationqueue(for:)
    private static let filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    /// Named after the open file, with a suffix so that dropping the copy
    /// next to its original doesn't collide with it.
    static func dragOutFileName(for sourceFileName: String?) -> String {
        guard let sourceFileName else { return "ImageAlpha.png" }
        let base = (sourceFileName as NSString).deletingPathExtension
        return "\(base)-quantized.png"
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        Self.dragOutOperations(for: context)
    }

    /// A copy, but only outside the app: inside it there's nowhere a dragged
    /// image should go, the canvas it came from included.
    static func dragOutOperations(for context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    // MARK: - NSFilePromiseProviderDelegate

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        fileNameForType fileType: String
    ) -> String {
        (filePromiseProvider.userInfo as? PromisedPNG)?.fileName ?? Self.dragOutFileName(for: nil)
    }

    /// Writes the PNG captured when the drag began, since the result may have
    /// moved on by the time the drop lands. Reports a failure rather than
    /// success with no file, and never replaces a file already at `url`.
    nonisolated func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        do {
            guard let promised = filePromiseProvider.userInfo as? PromisedPNG else {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSURLErrorKey: url])
            }
            try promised.data.write(to: url, options: .withoutOverwriting)
            handler(nil)
        } catch {
            handler(error)
        }
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        Self.filePromiseQueue
    }

    func beginImageDrag(from event: NSEvent) {
        guard let promised = dragOutProvider?() else { return }
        isDraggingOut = true

        let provider = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: self)
        provider.userInfo = promised

        let draggingItem = NSDraggingItem(pasteboardWriter: provider)
        draggingItem.setDraggingFrame(imageLayer.frame, contents: displayImage ?? originalImage)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
}
