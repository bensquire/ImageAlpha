---
title: Code Reads Like the Prose Around It
impact: HIGH
impactDescription: The next reader is a person, usually months later, often the author
tags: [quality, readability, naming]
paths: ["*.swift", "Views/**/*.swift", "ImageAlphaTests/**/*.swift"]
---

## Code Reads Like the Prose Around It

**Impact: HIGH**

Names say what a thing is in the words the domain uses — `effectiveOptions`,
`finalPNGData()`, `readStraightRGBA`, `packScanlines`,
`bitDepth(forPaletteCount:)`, `dragOutFileName(for:)` — so a call site reads as
a sentence. Short names are right where the convention uses them (`i`, `x`,
`r`, `g`, `b`) and wrong anywhere else. A
function does what its name says and nothing more; one that needs "and" in its
name is two. Nesting is shallow; the early `guard` says what a function
refuses, as `IndexedPNGEncoder.encode` refuses an empty palette or an index past
its end before doing any work. If a trick is necessary, the comment says why,
with the measurement.

**Incorrect:**

```swift
func depth(_ n: Int) -> Int {
    if n > 2 { if n > 4 { if n > 16 { return 8 }; return 4 }; return 2 }
    return 1
}
```

**Correct:**

```swift
/// Smallest PNG-legal bit depth (1, 2, 4 or 8) that can index the palette.
static func bitDepth(forPaletteCount count: Int) -> Int {
    switch count {
    case ...2: return 1
    case ...4: return 2
    case ...16: return 4
    default: return 8
    }
}
```
