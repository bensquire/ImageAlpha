import Foundation
import Testing

@testable import ImageAlpha

/// Serialized because tests swap the injected UserDefaults instance.
@Suite(.serialized)
struct PreferencesTests {

    /// Runs `body` with Preferences backed by an empty defaults suite. One
    /// fixed suite, emptied either side: removePersistentDomain(forName:)
    /// empties a suite but leaves its plist (and deleting that file doesn't
    /// stick; cfprefsd writes it back), so a fresh name per test left an empty
    /// plist behind each time.
    private func withTemporaryDefaults(_ body: () -> Void) {
        let suiteName = "ImageAlphaTests.Preferences"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        let original = Preferences.defaults
        Preferences.defaults = suite
        defer {
            Preferences.defaults = original
            suite.removePersistentDomain(forName: suiteName)
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
