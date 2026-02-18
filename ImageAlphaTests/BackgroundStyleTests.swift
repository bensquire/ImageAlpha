import Testing
@testable import ImageAlpha

struct BackgroundStyleTests {

    // MARK: - BackgroundStyle.id

    @Test func checkerboardId() {
        // Arrange
        let style = BackgroundStyle.checkerboard

        // Act
        let id = style.id

        // Assert
        #expect(id == "checkerboard")
    }

    @Test func colorId() {
        // Arrange
        let style = BackgroundStyle.color(red: 1, green: 0, blue: 0)

        // Act
        let id = style.id

        // Assert
        #expect(id == "color-1.0-0.0-0.0")
    }

    @Test func textureId() {
        // Arrange
        let style = BackgroundStyle.texture(name: "brick-wall-128x128", ext: "png")

        // Act
        let id = style.id

        // Assert
        #expect(id == "texture-brick-wall-128x128.png")
    }

    // MARK: - allBackgrounds

    @Test func allBackgroundsIsNotEmpty() {
        // Act
        let all = BackgroundStyle.allBackgrounds

        // Assert
        #expect(!all.isEmpty)
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

        // Assert
        #expect(!bg.canMove)
    }

    @Test func colorBackgroundMakesLayer() {
        // Arrange
        let bg = ColorBackground(r: 0.5, g: 0.5, b: 0.5)

        // Act
        let layer = bg.makeLayer()

        // Assert
        #expect(layer.backgroundColor != nil)
    }
}
