import Testing
import Foundation
@testable import ImageAlpha

/// Serialized because tests swap the injected UserDefaults instance.
@Suite(.serialized)
struct PreferencesTests {

    /// Runs `body` with Preferences backed by a throwaway defaults suite.
    private func withTemporaryDefaults(_ body: () -> Void) {
        let suiteName = "PreferencesTests-\(UUID().uuidString)"
        let temporary = UserDefaults(suiteName: suiteName)!
        let original = Preferences.defaults
        Preferences.defaults = temporary
        defer {
            Preferences.defaults = original
            temporary.removePersistentDomain(forName: suiteName)
        }
        body()
    }

    // MARK: - Speed

    @Test func speedDefaultsTo3WhenUnset() {
        withTemporaryDefaults {
            // Act
            let speed = Preferences.speed

            // Assert
            #expect(speed == 3)
        }
    }

    @Test func speedRoundTripsValidValue() {
        withTemporaryDefaults {
            // Arrange
            Preferences.speed = 10

            // Act
            let speed = Preferences.speed

            // Assert
            #expect(speed == 10)
        }
    }

    @Test func speedFallsBackToDefaultForOutOfRangeStoredValue() {
        withTemporaryDefaults {
            // Arrange
            Preferences.defaults.set(99, forKey: Preferences.Key.speed)

            // Act
            let speed = Preferences.speed

            // Assert
            #expect(speed == 3)
        }
    }

    // MARK: - Dithering tri-state

    @Test func ditheringIsNilWhenUnset() {
        withTemporaryDefaults {
            // Act
            let dithering = Preferences.dithering

            // Assert
            #expect(dithering == nil)
        }
    }

    @Test func ditheringRoundTripsTrueAndFalse() {
        withTemporaryDefaults {
            // Arrange & Act & Assert
            Preferences.dithering = true
            #expect(Preferences.dithering == true)

            Preferences.dithering = false
            #expect(Preferences.dithering == false)
        }
    }

    @Test func ditheringSetToNilClearsStoredValue() {
        withTemporaryDefaults {
            // Arrange
            Preferences.dithering = true

            // Act
            Preferences.dithering = nil

            // Assert
            #expect(Preferences.dithering == nil)
        }
    }

    // MARK: - ImageOptim

    @Test func optimizeWithImageOptimRoundTrips() {
        withTemporaryDefaults {
            // Arrange
            Preferences.optimizeWithImageOptim = true

            // Act & Assert
            #expect(Preferences.optimizeWithImageOptim)

            Preferences.optimizeWithImageOptim = false
            #expect(!Preferences.optimizeWithImageOptim)
        }
    }
}
