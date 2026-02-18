import Testing
@testable import ImageAlpha

struct QuantizerTypeTests {

    // MARK: - QuantizationOptions defaults

    @Test func defaultNumberOfColors() {
        // Act
        let options = QuantizationOptions()

        // Assert
        #expect(options.numberOfColors == 256)
    }

    @Test func defaultDitheringIsFalse() {
        // Act
        let options = QuantizationOptions()

        // Assert
        #expect(!options.dithering)
    }

    @Test func defaultIeModeIsFalse() {
        // Act
        let options = QuantizationOptions()

        // Assert
        #expect(!options.ieMode)
    }

    @Test func defaultSpeed() {
        // Act
        let options = QuantizationOptions()

        // Assert
        #expect(options.speed == 3)
    }

    // MARK: - QuantizationError descriptions

    @Test func failedToCreateAttrDescription() {
        // Arrange
        let error = QuantizationError.failedToCreateAttr

        // Act
        let desc = error.errorDescription

        // Assert
        #expect(desc == "Failed to create quantization attributes")
    }

    @Test func failedToCreateImageDescription() {
        // Arrange
        let error = QuantizationError.failedToCreateImage

        // Act
        let desc = error.errorDescription

        // Assert
        #expect(desc == "Failed to create quantization image")
    }

    @Test func failedToGetPixelDataDescription() {
        // Arrange
        let error = QuantizationError.failedToGetPixelData

        // Act
        let desc = error.errorDescription

        // Assert
        #expect(desc == "Failed to get pixel data from image")
    }

    @Test func failedToCreatePNGDescription() {
        // Arrange
        let error = QuantizationError.failedToCreatePNG

        // Act
        let desc = error.errorDescription

        // Assert
        #expect(desc == "Failed to create PNG data")
    }

    @Test func failedToQuantizeIncludesErrorCode() {
        // Arrange
        let error = QuantizationError.failedToQuantize(LIQ_QUALITY_TOO_LOW)

        // Act
        let desc = error.errorDescription

        // Assert
        #expect(desc?.contains("Quantization failed") == true)
        #expect(desc?.contains("\(LIQ_QUALITY_TOO_LOW.rawValue)") == true)
    }

    @Test func failedToRemapIncludesErrorCode() {
        // Arrange
        let error = QuantizationError.failedToRemap(LIQ_QUALITY_TOO_LOW)

        // Act
        let desc = error.errorDescription

        // Assert
        #expect(desc?.contains("Remapping failed") == true)
        #expect(desc?.contains("\(LIQ_QUALITY_TOO_LOW.rawValue)") == true)
    }
}
