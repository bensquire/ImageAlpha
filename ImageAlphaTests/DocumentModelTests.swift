import Testing
@testable import ImageAlpha

struct DocumentModelTests {

    // MARK: - bitDepthSliderValue getter

    @Test func sliderValueAt256Colors() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = 256 }

        // Act
        let value = await model.bitDepthSliderValue

        // Assert
        #expect(value == 8.0)
    }

    @Test func sliderValueAt128Colors() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = 128 }

        // Act
        let value = await model.bitDepthSliderValue

        // Assert
        #expect(value == 7.0)
    }

    @Test func sliderValueAbove256Is9() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = 257 }

        // Act
        let value = await model.bitDepthSliderValue

        // Assert
        #expect(value == 9.0)
    }

    @Test func sliderValueAt2ColorsIs1() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = 2 }

        // Act
        let value = await model.bitDepthSliderValue

        // Assert
        #expect(value == 1.0)
    }

    @Test func sliderValueAt1ColorIs1() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = 1 }

        // Act
        let value = await model.bitDepthSliderValue

        // Assert
        #expect(value == 1.0)
    }

    // MARK: - bitDepthSliderValue setter

    @Test func setSliderTo8Gives256Colors() async {
        // Arrange
        let model = await DocumentModel()

        // Act
        await MainActor.run { model.bitDepthSliderValue = 8.0 }
        let colors = await model.numberOfColors

        // Assert
        #expect(colors == 256)
    }

    @Test func setSliderTo5Gives32Colors() async {
        // Arrange
        let model = await DocumentModel()

        // Act
        await MainActor.run { model.bitDepthSliderValue = 5.0 }
        let colors = await model.numberOfColors

        // Assert
        #expect(colors == 32)
    }

    @Test func setSliderAbove8Gives257() async {
        // Arrange
        let model = await DocumentModel()

        // Act
        await MainActor.run { model.bitDepthSliderValue = 9.0 }
        let colors = await model.numberOfColors

        // Assert
        #expect(colors == 257)
    }

    @Test func setSliderTo1Gives2Colors() async {
        // Arrange
        let model = await DocumentModel()

        // Act
        await MainActor.run { model.bitDepthSliderValue = 1.0 }
        let colors = await model.numberOfColors

        // Assert
        #expect(colors == 2)
    }

    @Test func setSliderTo0Gives2Colors() async {
        // Arrange
        let model = await DocumentModel()

        // Act
        await MainActor.run { model.bitDepthSliderValue = 0.0 }
        let colors = await model.numberOfColors

        // Assert
        #expect(colors == 2)
    }

    // MARK: - bitDepthSliderValue roundtrips

    @Test func sliderRoundtripsForAllBitDepths() async {
        // Arrange
        let model = await DocumentModel()

        for bitDepth in 1...9 {
            // Act
            await MainActor.run { model.bitDepthSliderValue = Double(bitDepth) }
            let got = await model.bitDepthSliderValue

            // Assert
            #expect(got == Double(bitDepth))
        }
    }

    // MARK: - colorsDisplayString

    @Test func colorsDisplayStringAt256() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = 256 }

        // Act
        let display = await model.colorsDisplayString

        // Assert
        #expect(display == "256")
    }

    @Test func colorsDisplayStringAbove256() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = 257 }

        // Act
        let display = await model.colorsDisplayString

        // Assert
        #expect(display == "24-bit")
    }

    @Test func colorsDisplayStringAt2() async {
        // Arrange
        let model = await DocumentModel()
        await MainActor.run { model.numberOfColors = 2 }

        // Act
        let display = await model.colorsDisplayString

        // Assert
        #expect(display == "2")
    }

    // MARK: - formatStatus

    @Test func formatStatusWithAllFields() {
        // Act
        let result = DocumentModel.formatStatus(
            quantizedSize: 5000,
            sourceSize: 10000,
            sourceColorCount: 50000,
            colorsDisplay: "256"
        )

        // Assert
        #expect(result.contains("Original:"))
        #expect(result.contains("50,000 colours"))
        #expect(result.contains("10,000 bytes"))
        #expect(result.contains("Quantized:"))
        #expect(result.contains("256 colours"))
        #expect(result.contains("5,000 bytes"))
        #expect(result.contains("50% smaller"))
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
        #expect(result.contains("Quantized: ..."))
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

    @Test func formatStatusWith24BitColors() {
        // Act
        let result = DocumentModel.formatStatus(
            quantizedSize: 8000,
            sourceSize: 10000,
            sourceColorCount: 1000,
            colorsDisplay: "24-bit"
        )

        // Assert
        #expect(result.contains("24-bit colours"))
    }
}
