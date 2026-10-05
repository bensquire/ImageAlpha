import Testing
import AppKit
@testable import ImageAlpha

@MainActor
struct ImageAlphaDocumentTests {

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
