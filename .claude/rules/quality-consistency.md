---
title: Match the Code Around You
impact: HIGH
impactDescription: One idiom for one job, so a reader learns it once
tags: [quality, consistency, idioms, reuse]
paths: ["*.swift", "Views/**/*.swift", "ImageAlphaTests/**/*.swift"]
---

## Match the Code Around You

**Impact: HIGH**

New code reads like the file it lands in: the same naming, comment density,
error style, and idioms. Before writing a helper, look for the one that exists
and call it:

- `CheckerboardBackground.isDark(_:)` for light or dark from an appearance;
- `BackgroundStyle.textureImage` for a texture, cached and loaded with the
  subdirectory bundle API;
- `makeBackgroundRenderer(for:isDark:)` for a style's renderer;
- `IndexedPNGEncoder.bitDepth(forPaletteCount:)` and `encode(_:effort:)`;
- `Preferences` for any `UserDefaults` key;
- `DocumentModel.logger`'s pattern (`Logger(subsystem: "net.pornel.ImageAlpha", category: …)`)
  for logging.

In tests, the shared helpers are at the top of `IndexedPNGEncoderTests.swift`:
`DecodedImage`, `makeTestCGImage`, `encodeTruecolorPNG`, `encodeWithImageIO`,
`makeTemporaryDirectory`, `writeTemporaryFile`, `writeTestPNG`. A second
spelling of the same thing is a bug waiting for one of them to drift.

**Incorrect (a fresh spelling of an existing helper):**

```swift
let isDark = effectiveAppearance.name == .darkAqua   // misses the high-contrast dark appearance
```

**Correct:**

```swift
let isDark = CheckerboardBackground.isDark(effectiveAppearance)
```
