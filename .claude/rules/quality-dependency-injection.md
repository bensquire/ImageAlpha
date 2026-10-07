---
title: Dependencies and Settings Are Handed In as Values
impact: HIGH
impactDescription: Code that reaches for a global cannot be tested, varied or reused without it
tags: [quality, dependency-injection, values, testability]
paths: ["*.swift", "Views/**/*.swift", "ImageAlphaTests/**/*.swift"]
---

## Dependencies and Settings Are Handed In as Values

**Impact: HIGH**

A type takes its settings and collaborators as values, and whoever calls it
hands them in. `Quantizer.quantize` takes `QuantizationOptions`;
`IndexedPNGEncoder.encode` takes an `IndexedBitmap` and a `CompressionEffort`;
`DocumentModel.formatStatus` takes the `Locale` (the user's by default), so a
test can pin one; the document hands `DocumentModel` its `didChangeParameters`
callback; the canvas is handed a `dragOutProvider` rather than reaching for the
document. The work itself reads no `UserDefaults`, no environment and no
`NSApp`.

Preferences are read at the edges — `DocumentModel`'s initial values, the
Tools menu — and always through `Preferences`. Its `defaults` is the one seam
for swapping `UserDefaults`; tests swap it in a serialized suite. Reach for
that seam instead of adding a second.

When a knob is added, it is added once — on the type that uses it, such as a
field on `QuantizationOptions` — and reaches the quantizer through that value,
not as a second flag on every caller.

**Incorrect (the quantizer reading a preference; a status line pinned to the current locale):**

```swift
liq_set_dithering_level(result, Preferences.dithering == true ? 1.0 : 0.0)
let size = quantizedSize.formatted(.number.locale(.current))
```

**Correct:**

```swift
liq_set_dithering_level(result, options.dithering ? 1.0 : 0.0)
nonisolated static func formatStatus(…, locale: Locale = .current) -> String
```
