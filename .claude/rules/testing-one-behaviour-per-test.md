---
title: One Behaviour Per Test, Named as a Sentence
impact: HIGH
impactDescription: A test of several things fails for one and hides the rest
tags: [testing, naming, scope, swift-testing]
paths: ["ImageAlphaTests/**/*.swift"]
---

## One Behaviour Per Test, Named as a Sentence

**Impact: HIGH**

A test pins one behaviour, and its name says which, as a sentence that reads in
the report: `failedLoadKeepsThePreviousImage`,
`aBurstOfParameterChangesMarksTheDocumentEditedOnce`,
`omitsTRNSChunkWhenPaletteFullyOpaque`. A name with "and" that lists unrelated
checks is usually two tests; one with "and" that describes a single outcome is
fine (`maximumEffortDecodesIdenticallyAndIsNoLarger`). When the same behaviour
is asked of several inputs, use `@Test(arguments:)`, or a loop whose every
`#expect` names its input, rather than copying the test.

Test the behaviour, not the implementation: what the decoded PNG contains,
whether the document is marked edited, what the status line says — not which
private function ran. `@testable` is for reaching a real internal seam like
`IndexedPNGEncoder.packScanlines` or `DocumentModel.formatStatus`, not for
asserting on scaffolding.

**Incorrect:**

```swift
@Test func quantizerWorks() async throws {
    // checks colour type, dimensions, palette size, transparency and file size in one go
}
```

**Correct:**

```swift
@Test func producesIndexedColorTypePNG() async throws { … }
@Test func outputDecodesToOriginalDimensions() async throws { … }
@Test(arguments: [(2, 1), (4, 2), (16, 4), (17, 8), (256, 8)])
func bitDepthFitsThePalette(count: Int, depth: Int) { … }
```
