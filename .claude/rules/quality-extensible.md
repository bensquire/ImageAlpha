---
title: Add a Case and Its Behaviour, Not an `if`
impact: HIGH
impactDescription: A special case on shared code is a band-aid the next change tears off
tags: [quality, extensibility, altitude, design]
paths: ["*.swift", "Views/**/*.swift"]
---

## Add a Case and Its Behaviour, Not an `if`

**Impact: HIGH**

The places the app grows are enumerations with one mechanism behind each:

- A **background** is a `BackgroundStyle` case listed in `allBackgrounds`. Its
  name for VoiceOver comes from `accessibilityName`, its image from
  `textureImage`, and its renderer from `makeBackgroundRenderer(for:isDark:)`,
  one of the three `BackgroundRendering` types. A new texture is a PNG in
  `textures/`, credited in `textures/README.md`, and one line in
  `allBackgrounds`.
- A **quantization mode** is a `QuantizationMode` case, and
  `DocumentModel.effectiveOptions` is the one place it becomes options.
- A **compression effort** is an `IndexedPNGEncoder.CompressionEffort` case
  that `encode` switches on.

The switches are exhaustive, so a new case makes the compiler list every place
that has to decide what it means. Adding one means adding a case and its
behaviour — not an `if` in the canvas or the encoder for the new one.

When a change wants a special case on shared code, the fix is usually one level
deeper: give the shared mechanism what the case needs.

**Incorrect (the canvas learns about one texture):**

```swift
if style.id == "texture-brick-wall-128x128.png" { layer.contentsScale = 2 }
```

**Correct (the case carries what it needs through the one mechanism):**

```swift
static let allBackgrounds: [BackgroundStyle] = [
    …
    .texture(name: "brick-wall-128x128", ext: "png"),
]
```
