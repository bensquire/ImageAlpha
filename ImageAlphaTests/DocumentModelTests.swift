import Foundation
import Testing

@testable import ImageAlpha

struct DocumentModelTests {

    // MARK: - Loading

    @MainActor @Test func failedLoadKeepsThePreviousImage() throws {
        // Arrange
        let good = try writeTestPNG(named: "good.png")
        let broken = try writeTemporaryFile(named: "broken.png", contents: Data("not a png".utf8))
        let model = DocumentModel()
        try model.loadImage(from: good)

        // Act
        #expect(throws: (any Error).self) { try model.loadImage(from: broken) }

        // Assert
        #expect(model.sourceURL == good)
        #expect(model.sourceImage != nil)
    }

    @MainActor @Test func openingAnImageLeavesTheDocumentUnedited() async throws {
        // Arrange
        let model = DocumentModel()
        var edits = 0

        // Act: as ImageAlphaDocument does: read, then make its window controllers
        try model.loadImage(from: writeTestPNG(named: "image.png"))
        model.didChangeParameters = { edits += 1 }
        try await Task.sleep(for: .milliseconds(200))

        // Assert
        #expect(edits == 0)
    }

    @MainActor @Test func aBurstOfParameterChangesMarksTheDocumentEditedOnce() async throws {
        // Arrange
        let model = DocumentModel()
        try model.loadImage(from: writeTestPNG(named: "image.png"))
        var edits = 0
        model.didChangeParameters = { edits += 1 }

        // Act: as a slider being scrubbed
        model.numberOfColors = 128
        model.numberOfColors = 64
        model.numberOfColors = 32
        try await Task.sleep(for: .milliseconds(200))

        // Assert
        #expect(edits == 1)
    }

    // MARK: - bitDepthSliderValue

    @Test(arguments: [(256, 8.0), (128, 7.0), (257, 9.0), (2, 1.0), (1, 1.0)])
    func sliderShowsTheBitDepthOfTheColorCount(colors: Int, sliderValue: Double) async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = colors }

        // Act
        let value = await model.bitDepthSliderValue

        // Assert
        #expect(value == sliderValue)
    }

    @Test(arguments: [(8.0, 256), (5.0, 32), (9.0, 257), (1.0, 2), (0.0, 2)])
    func movingTheSliderPicksAColorCount(sliderValue: Double, colors: Int) async {
        // Arrange
        let model = await DocumentModel()

        // Act
        await MainActor.run { model.bitDepthSliderValue = sliderValue }

        // Assert
        let count = await model.numberOfColors
        #expect(count == colors)
    }

    @Test(arguments: 1...9)
    func sliderReadsBackEveryBitDepthItIsSetTo(bitDepth: Int) async {
        // Arrange
        let model = await DocumentModel()

        // Act
        await MainActor.run { model.bitDepthSliderValue = Double(bitDepth) }

        // Assert
        let value = await model.bitDepthSliderValue
        #expect(value == Double(bitDepth))
    }

    // MARK: - colorsDisplayString

    @Test(arguments: [256, 2])
    func colorsDisplayStringShowsTheColorCount(colors: Int) async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = colors }

        // Act
        let display = await model.colorsDisplayString

        // Assert
        #expect(display == "\(colors)")
    }

    @Test func colorsAbove256DisplayAs24Bit() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = 257 }

        // Act
        let display = await model.colorsDisplayString

        // Assert
        #expect(display == "24-bit")
    }

    // MARK: - formatStatus

    @Test func formatStatusWithAllFields() {
        // Act
        let result = DocumentModel.formatStatus(
            quantizedSize: 5000,
            sourceSize: 10000,
            sourceColorCount: 50000,
            colorsDisplay: "256",
            locale: Locale(identifier: "en_US")
        )

        // Assert
        #expect(result.contains("Original:"))
        #expect(result.contains("50,000 colors"))
        #expect(result.contains("10,000 bytes"))
        #expect(result.contains("Quantized:"))
        #expect(result.contains("256 colors"))
        #expect(result.contains("5,000 bytes"))
        #expect(result.contains("50% smaller"))
    }

    @Test func formatStatusGroupsDigitsTheLocalesWay() {
        // Act
        let result = DocumentModel.formatStatus(
            quantizedSize: 5000,
            sourceSize: 10000,
            sourceColorCount: 50000,
            colorsDisplay: "256",
            locale: Locale(identifier: "de_DE")
        )

        // Assert
        #expect(result.contains("50.000 colors"))
        #expect(result.contains("5.000 bytes"))
    }

    @Test func formatStatusShowsBiggerWhenQuantizedIsLarger() {
        // Act
        let result = DocumentModel.formatStatus(
            quantizedSize: 15000,
            sourceSize: 10000,
            sourceColorCount: 100,
            colorsDisplay: "256"
        )

        // Assert
        #expect(result.contains("50% bigger"))
    }

    @Test func formatStatusWithoutSourceColorCount() {
        // Act
        let result = DocumentModel.formatStatus(
            quantizedSize: 5000,
            sourceSize: 10000,
            sourceColorCount: nil,
            colorsDisplay: "256"
        )

        // Assert
        #expect(result.contains("Original:"))
        #expect(result.contains("10,000 bytes"))
        #expect(result.contains("Quantized: …"))
    }

    @Test func formatStatusWithoutSourceSize() {
        // Act
        let result = DocumentModel.formatStatus(
            quantizedSize: 5000,
            sourceSize: nil,
            sourceColorCount: nil,
            colorsDisplay: "256"
        )

        // Assert
        #expect(result.starts(with: "Quantized:"))
        #expect(result.contains("5,000 bytes"))
        #expect(!result.contains("smaller"))
        #expect(!result.contains("bigger"))
    }

    @Test func formatStatusIncludesQualityWhenAvailable() {
        // Act
        let result = DocumentModel.formatStatus(
            quantizedSize: 5000,
            sourceSize: 10000,
            sourceColorCount: 100,
            colorsDisplay: "256",
            quality: 93
        )

        // Assert
        #expect(result.contains("quality: 93%"))
    }

    @Test func formatStatusOmitsQualityWhenNil() {
        // Act
        let result = DocumentModel.formatStatus(
            quantizedSize: 5000,
            sourceSize: 10000,
            sourceColorCount: 100,
            colorsDisplay: "256",
            quality: nil
        )

        // Assert
        #expect(!result.contains("quality"))
    }

    // MARK: - Quality mode display

    @Test func colorsDisplayStringInQualityModeShowsResultPaletteCount() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run {
            model.quantizationMode = .quality
            model.resultStats = QuantizationStats(paletteCount: 152, quality: nil)
        }

        // Act
        let display = await model.colorsDisplayString

        // Assert
        #expect(display == "152")
    }

    @Test func colorsDisplayStringInQualityModeWithoutResultIsPlaceholder() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.quantizationMode = .quality }

        // Act
        let display = await model.colorsDisplayString

        // Assert
        #expect(display == "…")
    }

    @Test func formatStatusWith24BitColors() {
        // Act
        let result = DocumentModel.formatStatus(
            quantizedSize: 8000,
            sourceSize: 10000,
            sourceColorCount: 1000,
            colorsDisplay: "24-bit"
        )

        // Assert
        #expect(result.contains("24-bit colors"))
    }
}
