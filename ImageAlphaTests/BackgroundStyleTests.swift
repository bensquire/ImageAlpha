import CoreGraphics
import Testing

@testable import ImageAlpha

struct BackgroundStyleTests {

    // MARK: - BackgroundStyle.id

    @Test(arguments: [
        (BackgroundStyle.checkerboard, "checkerboard"),
        (.color(red: 1, green: 0, blue: 0), "color-1.0-0.0-0.0"),
        (.texture(name: "brick-wall-128x128", ext: "png"), "texture-brick-wall-128x128.png"),
    ])
    func idSpellsOutTheStyle(style: BackgroundStyle, expectedID: String) {
        // Act
        let id = style.id

        // Assert
        #expect(id == expectedID)
    }

    // MARK: - Accessibility names

    @Test func textureIsNamedFromItsFile() {
        // Act
        let name = BackgroundStyle.texture(name: "white-gravel-128x128", ext: "png").accessibilityName

        // Assert
        #expect(name == "White gravel")
    }

    @Test func primaryColorIsNamed() {
        // Act
        let name = BackgroundStyle.color(red: 0, green: 0, blue: 1).accessibilityName

        // Assert
        #expect(name == "Blue")
    }

    // MARK: - Texture images

    @Test func textureImageIsLoadedOnce() throws {
        // Arrange
        let style = BackgroundStyle.texture(name: "brick-wall-128x128", ext: "png")

        // Act
        let first = try #require(style.textureImage)
        let second = try #require(style.textureImage)

        // Assert: the same object, not a second read from disk
        #expect(first === second)
    }

    @Test func checkerboardHasNoTextureImage() {
        // Act
        let image = BackgroundStyle.checkerboard.textureImage

        // Assert
        #expect(image == nil)
    }

    // MARK: - allBackgrounds

    @Test func everyTextureInAllBackgroundsShipsInTheBundle() {
        // Arrange: the test host is the app, so its bundle is the one that ships
        let textures = BackgroundStyle.allBackgrounds.filter {
            if case .texture = $0 { true } else { false }
        }

        // Act
        let missing = textures.filter { $0.textureImage == nil }.map(\.id)

        // Assert
        #expect(textures.count == 8)
        #expect(missing.isEmpty, "not in the bundle: \(missing)")
    }

    @Test func allBackgroundsStartsWithCheckerboard() {
        // Act
        let first = BackgroundStyle.allBackgrounds.first

        // Assert
        #expect(first == .checkerboard)
    }

    @Test func allBackgroundsHasUniqueIds() {
        // Arrange
        let all = BackgroundStyle.allBackgrounds

        // Act
        let ids = all.map(\.id)
        let uniqueIds = Set(ids)

        // Assert
        #expect(ids.count == uniqueIds.count)
    }

    @Test func allBackgroundsContains12Items() {
        // Act
        let count = BackgroundStyle.allBackgrounds.count

        // Assert
        #expect(count == 12)
    }

    // MARK: - ColorBackground

    @Test func colorBackgroundCannotMove() {
        // Arrange
        let bg = ColorBackground(r: 1, g: 0, b: 0)

        // Act
        let canMove = bg.canMove

        // Assert
        #expect(!canMove)
    }

    @Test func colorBackgroundFillsItsLayerWithItsColor() throws {
        // Arrange
        let bg = ColorBackground(r: 0.5, g: 0.25, b: 0)

        // Act
        let layer = bg.makeLayer()

        // Assert: the sRGB colour it was given, opaque
        let color = try #require(layer.backgroundColor)
        #expect(color.components == [0.5, 0.25, 0, 1])
        #expect(color.colorSpace?.name == CGColorSpace.sRGB)
    }

    // MARK: - CheckerboardBackground

    @Test func checkerboardCannotMove() {
        // Arrange
        let bg = CheckerboardBackground(isDark: false)

        // Act
        let canMove = bg.canMove

        // Assert
        #expect(!canMove)
    }

    @Test(arguments: [(false, 1.0), (true, 0.30)])
    func checkerboardLightSquaresFollowTheAppearance(isDark: Bool, white: Double) {
        // Act
        let shade = CheckerboardBackground.checkerLightWhite(isDark: isDark)

        // Assert
        #expect(shade == CGFloat(white))
    }

    @Test(arguments: [(false, 0.86), (true, 0.24)])
    func checkerboardDarkSquaresFollowTheAppearance(isDark: Bool, white: Double) {
        // Act
        let shade = CheckerboardBackground.checkerDarkWhite(isDark: isDark)

        // Assert
        #expect(shade == CGFloat(white))
    }
}
