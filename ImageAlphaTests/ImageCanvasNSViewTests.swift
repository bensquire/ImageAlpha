import Testing
import AppKit
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
            let context = try #require(CGContext(
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

    private func pasteboard(holding url: URL) -> NSPasteboard {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
        return pasteboard
    }

    // MARK: - Touches

    @Test func acceptsTrackpadTouches() {
        // Act
        let view = ImageCanvasNSView(frame: .zero)

        // Assert: NSView accepts only direct (Touch Bar) touches by default
        #expect(view.allowedTouchTypes.contains(.indirect))
    }

    // MARK: - Resizing

    @Test func refitsImageWhenResizedBySetFrameSize() throws {
        // Arrange: a 100-point image fitted into 200 points is shown at 2×
        let view = ImageCanvasNSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        view.originalImage = try makeImage(width: 100, height: 100)

        // Act
        view.setFrameSize(NSSize(width: 300, height: 300))

        // Assert
        #expect(view.currentZoom == 3)
    }

    @Test func refitsImageWhenFrameIsSet() throws {
        // Arrange
        let view = ImageCanvasNSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        view.originalImage = try makeImage(width: 100, height: 100)

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

    // MARK: - Drag out

    @Test func filePromiseWritesTheDataCapturedAtDragStart() async throws {
        // Arrange
        let view = ImageCanvasNSView(frame: .zero)
        view.pngDataProvider = { Data([9, 9]) }
        let provider = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: view)
        provider.userInfo = Data([1, 2, 3])
        let url = try makeTemporaryDirectory().appendingPathComponent("dragged.png")

        // Act
        let error = await withCheckedContinuation { continuation in
            view.filePromiseProvider(provider, writePromiseTo: url) { continuation.resume(returning: $0) }
        }

        // Assert
        #expect(error == nil)
        #expect(try Data(contentsOf: url) == Data([1, 2, 3]))
    }

    @Test func filePromiseFailsWhenThereIsNoData() async throws {
        // Arrange
        let view = ImageCanvasNSView(frame: .zero)
        let provider = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: view)
        let url = try makeTemporaryDirectory().appendingPathComponent("dragged.png")

        // Act
        let error = await withCheckedContinuation { continuation in
            view.filePromiseProvider(provider, writePromiseTo: url) { continuation.resume(returning: $0) }
        }

        // Assert: the receiver is told, rather than shown success and no file
        #expect(error != nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func filePromisesAreWrittenOffTheMainQueue() {
        // Arrange
        let view = ImageCanvasNSView(frame: .zero)
        let provider = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: view)

        // Act
        let queue = view.operationQueue(for: provider)

        // Assert
        #expect(queue !== OperationQueue.main)
    }

    // MARK: - Drop target

    @Test func acceptsDroppedPNGFiles() throws {
        // Arrange
        let url = try writeTestPNG(named: "image.png")
        let view = ImageCanvasNSView(frame: .zero)

        // Act
        let accepted = view.hasDocumentFileURLs(pasteboard(holding: url))

        // Assert
        #expect(accepted)
    }

    @Test func refusesDroppedImagesItCannotSaveBackTo() throws {
        // Arrange: a JPEG would be overwritten with PNG bytes on Save
        let pixels = [UInt8](repeating: 255, count: 4 * 4 * 4)
        let jpeg = try encodeWithImageIO(makeTestCGImage(width: 4, height: 4, rgba: pixels), as: .jpeg)
        let url = try writeTemporaryFile(named: "photo.jpg", contents: jpeg)
        let view = ImageCanvasNSView(frame: .zero)

        // Act
        let accepted = view.hasDocumentFileURLs(pasteboard(holding: url))

        // Assert
        #expect(!accepted)
    }
}
