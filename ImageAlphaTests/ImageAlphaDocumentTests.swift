import AppKit
import Testing

@testable import ImageAlpha

/// Stands in for whoever asked for a save (the close sheet, quit review),
/// recording what NSDocument's didSave callback reports.
final class SaveRecorder: NSObject {
    struct Result {
        let document: NSDocument
        let didSave: Bool
        let contextInfo: UnsafeMutableRawPointer?
    }

    private(set) var results: [Result] = []

    @objc func document(_ document: NSDocument, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        results.append(Result(document: document, didSave: didSave, contextInfo: contextInfo))
    }
}

@MainActor
struct ImageAlphaDocumentTests {

    // MARK: - Overwrite confirmation

    @Test func cancellingTheOverwriteTellsTheCallerNothingWasSaved() throws {
        // Arrange: a close or quit waits on this answer before going ahead
        let url = try writeTestPNG(named: "image.png")
        let original = try Data(contentsOf: url)
        let document = try ImageAlphaDocument(contentsOf: url, ofType: "public.png")
        let recorder = SaveRecorder()
        let context = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
        defer { context.deallocate() }

        // Act
        document.continueSave(
            after: .alertThirdButtonReturn, delegate: recorder,
            didSave: #selector(SaveRecorder.document(_:didSave:contextInfo:)), contextInfo: context
        )

        // Assert
        let result = try #require(recorder.results.first)
        #expect(recorder.results.count == 1)
        #expect(result.document === document)
        #expect(!result.didSave)
        #expect(result.contextInfo == context)
        #expect(try Data(contentsOf: url) == original)
    }

    // MARK: - Reading

    @Test func readingLoadsTheImage() throws {
        // Arrange
        let url = try writeTestPNG(named: "image.png")
        let document = ImageAlphaDocument()

        // Act
        try document.read(from: url, ofType: "public.png")

        // Assert
        #expect(document.model.sourceImage != nil)
    }

    @Test func readingAFileThatIsNotAnImageThrows() throws {
        // Arrange: the error must reach NSDocument, which shows it, rather
        // than leave an empty window behind
        let url = try writeTemporaryFile(named: "broken.png", contents: Data("not a png".utf8))
        let document = ImageAlphaDocument()

        // Act / Assert
        #expect(throws: (any Error).self) { try document.read(from: url, ofType: "public.png") }
    }
}
