import Foundation

/// Central access to app-wide preferences. All UserDefaults keys and their
/// validation rules live here so views, documents, and menus stay in sync.
enum Preferences {

    enum Key {
        static let dithered = "dithered"
        static let speed = "speed"
        static let optimizeWithImageOptim = "optimizeWithImageOptim"
    }

    /// Injectable for tests; production code always uses .standard.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static let defaultSpeed = 3
    static let speedRange = 1...10

    /// Tri-state: nil means "Automatic" (no explicit user choice).
    static var dithering: Bool? {
        get { defaults.object(forKey: Key.dithered) as? Bool }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Key.dithered)
            } else {
                defaults.removeObject(forKey: Key.dithered)
            }
        }
    }

    /// Always returns a valid libimagequant speed; out-of-range stored values
    /// (including the 0 an unset key reads as) fall back to the default.
    static var speed: Int {
        get {
            let stored = defaults.integer(forKey: Key.speed)
            return speedRange.contains(stored) ? stored : defaultSpeed
        }
        set { defaults.set(newValue, forKey: Key.speed) }
    }

    static var optimizeWithImageOptim: Bool {
        get { defaults.bool(forKey: Key.optimizeWithImageOptim) }
        set { defaults.set(newValue, forKey: Key.optimizeWithImageOptim) }
    }
}
