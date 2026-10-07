import AppKit
import Testing
import UniformTypeIdentifiers

@testable import ImageAlpha

@MainActor
struct ImageCanvasNSViewTests {

    // MARK: - Helpers

    private func makeImage(width: Int, height: Int) throws -> NSImage {
        let pixels = [UInt8](repeating: 255, count: width * height * 4)
        let cgImage = try makeTestCGImage(width: width, height: height, rgba: pixels)
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    /// The red channel of the brightest pixel the view's layers draw, away
    /// from the edge shadows (top 10 and left 12 points).
    private func brightestRed(renderedFrom view: ImageCanvasNSView) throws -> UInt8 {
        let width = Int(view.bounds.width), height = Int(view.bounds.height)
        let layer = try #require(view.layer)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(
                CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ))
            layer.render(in: context)
        }
        var brightest: UInt8 = 0
        for row in 16..<height {
            for col in 16..<width {
                brightest = max(brightest, pixels[(row * width + col) * 4])
            }
        }
        return brightest
    }

    private func promise(of type: UTType, from view: ImageCanvasNSView) -> NSFilePromiseProvider {
        NSFilePromiseProvider(fileType: type.identifier, delegate: view)
    }

    private func pasteboard(holding item: any NSPasteboardWriting) -> NSPasteboard {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        return pasteboard
    }

    /// A pixel-precise scroll, as a trackpad sends.
    private func scrollEvent(dx: Int32, dy: Int32, flags: CGEventFlags = []) throws -> NSEvent {
        let cgEvent = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0
            ))
        cgEvent.flags = flags
        return try #require(NSEvent(cgEvent: cgEvent))
    }

    /// A square view of the given side fitted to a 100-point image, so at
    /// 2× for the default 200.
    private func makeViewShowingImage(side: CGFloat = 200) throws -> ImageCanvasNSView {
        let view = ImageCanvasNSView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        view.originalImage = try makeImage(width: 100, height: 100)
        return view
    }

    private func writePromise(_ provider: NSFilePromiseProvider, of view: ImageCanvasNSView, to url: URL)
        async -> Error?
    {
        await withCheckedContinuation { continuation in
            view.filePromiseProvider(provider, writePromiseTo: url) { continuation.resume(returning: $0) }
        }
    }

    // MARK: - Resizing

    @Test func refitsImageWhenResizedBySetFrameSize() throws {
        // Arrange: shown at 2×
        let view = try makeViewShowingImage()

        // Act
        view.setFrameSize(NSSize(width: 300, height: 300))

        // Assert
        #expect(view.currentZoom == 3)
    }

    @Test func refitsImageWhenFrameIsSet() throws {
        // Arrange
        let view = try makeViewShowingImage()

        // Act
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 300)

        // Assert
        #expect(view.currentZoom == 3)
    }

    // MARK: - Appearance

    @Test func checkerboardFollowsTheViewsAppearance() throws {
        // Arrange: the view is dark while the thread's drawing appearance is
        // light, as when an appearance change arrives outside a drawing pass
        let view = ImageCanvasNSView(frame: NSRect(x: 0, y: 0, width: 64, height: 64))
        view.appearance = NSAppearance(named: .darkAqua)
        let aqua = try #require(NSAppearance(named: .aqua))

        // Act
        aqua.performAsCurrentDrawingAppearance { view.checkerboardStyle = .checkerboard }

        // Assert: the light squares are dark mode's 30% grey, not white
        let brightest = try brightestRed(renderedFrom: view)
        #expect(brightest < 128, "light squares drew at \(brightest)/255")
    }

    // MARK: - Scrolling

    @Test func scrollingPansTheImage() throws {
        // Arrange
        let view = try makeViewShowingImage()
        let zoom = view.currentZoom

        // Act: scroll up and to the left
        view.scrollWheel(with: try scrollEvent(dx: 5, dy: 10))

        // Assert: the image follows, right and down, at the same zoom
        #expect(view.imageOffset == CGPoint(x: 5, y: -10))
        #expect(view.currentZoom == zoom)
    }

    @Test func commandScrollingZoomsFromTheZoomShown() throws {
        // Arrange: fitted at 3×, not the 2× the view starts with
        let view = try makeViewShowingImage(side: 300)

        // Act: past the 40-point threshold for precise deltas
        view.scrollWheel(with: try scrollEvent(dx: 0, dy: 50, flags: .maskCommand))

        // Assert
        #expect(view.currentZoom == 6)
        #expect(view.imageOffset == .zero)
    }

    // MARK: - Cursor

    @Test func cursorIsAHandOverTheImage() throws {
        // Arrange
        let view = try makeViewShowingImage()

        // Act
        let cursor = view.cursor(at: NSPoint(x: 20, y: 20))

        // Assert
        #expect(cursor === NSCursor.openHand)
    }

    @Test func cursorClosesWhileTheMouseIsDown() throws {
        // Arrange
        let view = try makeViewShowingImage()
        view.mouseIsDown = true

        // Act
        let cursor = view.cursor(at: NSPoint(x: 20, y: 20))

        // Assert
        #expect(cursor === NSCursor.closedHand)
    }

    @Test func cursorResizesOverTheCompareDivider() throws {
        // Arrange: the divider sits at x = 100
        let view = try makeViewShowingImage()
        view.splitPosition = 0.5

        // Act
        let cursor = view.cursor(at: NSPoint(x: 104, y: 20))

        // Assert
        #expect(cursor === NSCursor.resizeLeftRight)
    }

    // MARK: - Drag out

    @Test func dragOutIsNamedAfterTheOpenFile() {
        // Act
        let name = ImageCanvasNSView.dragOutFileName(for: "dice.v2.png")

        // Assert
        #expect(name == "dice.v2-quantized.png")
    }

    @Test func filePromiseWritesTheDataCapturedAtDragStart() async throws {
        // Arrange
        let view = ImageCanvasNSView(frame: .zero)
        view.dragOutProvider = { PromisedPNG(data: Data([9, 9]), fileName: "later.png") }
        let provider = promise(of: .png, from: view)
        provider.userInfo = PromisedPNG(data: Data([1, 2, 3]), fileName: "dice-quantized.png")
        let url = try makeTemporaryDirectory().appendingPathComponent("dragged.png")

        // Act
        let error = await writePromise(provider, of: view, to: url)

        // Assert
        #expect(error == nil)
        #expect(try Data(contentsOf: url) == Data([1, 2, 3]))
    }

    @Test func filePromiseIsNamedWhenTheDragStarts() {
        // Arrange: the name captured at drag start, not the one the provider would give now
        let view = ImageCanvasNSView(frame: .zero)
        view.dragOutProvider = { PromisedPNG(data: Data([9, 9]), fileName: "later.png") }
        let provider = promise(of: .png, from: view)
        provider.userInfo = PromisedPNG(data: Data([1, 2, 3]), fileName: "dice-quantized.png")

        // Act
        let name = view.filePromiseProvider(provider, fileNameForType: UTType.png.identifier)

        // Assert
        #expect(name == "dice-quantized.png")
    }

    @Test func filePromiseNeverReplacesAnExistingFile() async throws {
        // Arrange
        let view = ImageCanvasNSView(frame: .zero)
        let provider = promise(of: .png, from: view)
        provider.userInfo = PromisedPNG(data: Data([1, 2, 3]), fileName: "dice-quantized.png")
        let url = try writeTemporaryFile(named: "dice-quantized.png", contents: Data([7]))

        // Act
        let error = await writePromise(provider, of: view, to: url)

        // Assert
        #expect(error != nil)
        #expect(try Data(contentsOf: url) == Data([7]))
    }

    @Test func filePromiseFailsWhenThereIsNoData() async throws {
        // Arrange
        let view = ImageCanvasNSView(frame: .zero)
        let provider = promise(of: .png, from: view)
        let url = try makeTemporaryDirectory().appendingPathComponent("dragged.png")

        // Act
        let error = await writePromise(provider, of: view, to: url)

        // Assert: the receiver is told, rather than shown success and no file
        #expect(error != nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func filePromisesAreWrittenOffTheMainQueue() {
        // Arrange
        let view = ImageCanvasNSView(frame: .zero)
        let provider = promise(of: .png, from: view)

        // Act
        let queue = view.operationQueue(for: provider)

        // Assert
        #expect(queue !== OperationQueue.main)
    }

    // MARK: - Drop target

    @Test func offersACopyOfPNGFilesWhenTheSourcePermitsIt() throws {
        // Arrange: Finder permits copying a file it drags
        let url = try writeTestPNG(named: "image.png")
        let view = ImageCanvasNSView(frame: .zero)

        // Act
        let operation = view.dropOperation(
            for: pasteboard(holding: url as NSURL), sourceMask: [.copy, .move, .link])

        // Assert
        #expect(operation == .copy)
    }

    @Test func offersACopyOfPromisedPNGFiles() {
        // Arrange: what Photos, Mail or a browser puts on the drag pasteboard
        let view = ImageCanvasNSView(frame: .zero)

        // Act
        let operation = view.dropOperation(
            for: pasteboard(holding: promise(of: .png, from: view)), sourceMask: .copy)

        // Assert
        #expect(operation == .copy)
    }

    @Test func refusesItsOwnDragOut() {
        // Arrange: the mask the canvas gives its own drag inside the app
        let view = ImageCanvasNSView(frame: .zero)
        let mask = ImageCanvasNSView.dragOutOperations(for: .withinApplication)

        // Act
        let operation = view.dropOperation(
            for: pasteboard(holding: promise(of: .png, from: view)), sourceMask: mask)

        // Assert: let go over itself, it isn't reopened as a copy
        #expect(operation.isEmpty)
    }

    @Test func refusesPromisedFilesItCannotOpen() {
        // Arrange
        let view = ImageCanvasNSView(frame: .zero)

        // Act
        let operation = view.dropOperation(
            for: pasteboard(holding: promise(of: .jpeg, from: view)), sourceMask: .copy)

        // Assert
        #expect(operation.isEmpty)
    }

    @Test func refusesDroppedImagesItCannotSaveBackTo() throws {
        // Arrange: a JPEG would be overwritten with PNG bytes on Save
        let pixels = [UInt8](repeating: 255, count: 4 * 4 * 4)
        let jpeg = try encodeWithImageIO(makeTestCGImage(width: 4, height: 4, rgba: pixels), as: .jpeg)
        let url = try writeTemporaryFile(named: "photo.jpg", contents: jpeg)
        let view = ImageCanvasNSView(frame: .zero)

        // Act
        let operation = view.dropOperation(for: pasteboard(holding: url as NSURL), sourceMask: .copy)

        // Assert
        #expect(operation.isEmpty)
    }
}
