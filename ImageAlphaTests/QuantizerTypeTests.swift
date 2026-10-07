import Testing

@testable import ImageAlpha

struct QuantizerTypeTests {

    // MARK: - QuantizationOptions defaults

    @Test func optionsDefaultTo256Colors() {
        // Act
        let options = QuantizationOptions()

        // Assert
        #expect(options.numberOfColors == 256)
    }

    @Test func optionsDefaultToNoDithering() {
        // Act
        let options = QuantizationOptions()

        // Assert
        #expect(!options.dithering)
    }

    @Test func optionsDefaultToSpeed3() {
        // Act
        let options = QuantizationOptions()

        // Assert
        #expect(options.speed == 3)
    }

    // MARK: - QuantizationError descriptions

    @Test(arguments: [
        (QuantizationError.failedToCreateAttr, "Failed to create quantization attributes"),
        (.failedToCreateImage, "Failed to create quantization image"),
        (.failedToGetPixelData, "Failed to get pixel data from image"),
        (.failedToCreatePNG, "Failed to create PNG data"),
    ])
    func errorSaysWhatFailed(error: QuantizationError, description: String) {
        // Act
        let desc = error.errorDescription

        // Assert
        #expect(desc == description)
    }

    @Test(arguments: [
        (QuantizationError.failedToQuantize(LIQ_QUALITY_TOO_LOW), "Quantization failed"),
        (.failedToRemap(LIQ_QUALITY_TOO_LOW), "Remapping failed"),
    ])
    func libimagequantErrorCarriesItsCode(error: QuantizationError, prefix: String) {
        // Act
        let desc = error.errorDescription

        // Assert
        #expect(desc?.contains(prefix) == true)
        #expect(desc?.contains("\(LIQ_QUALITY_TOO_LOW.rawValue)") == true)
    }
}
