---
title: A Failure Reads as a Sentence
impact: MEDIUM
impactDescription: A bare comparison fails as a pair of values with no story
tags: [testing, expectations, messages, swift-testing]
paths: ["ImageAlphaTests/**/*.swift"]
---

## A Failure Reads as a Sentence

**Impact: MEDIUM**

Swift Testing already prints both sides of a failed `#expect`, so a single
comparison whose expression says what it checks (`#expect(decoded.width ==
40)`) needs nothing more. An `#expect` gets a message when the expression
alone wouldn't say which case failed or why it matters: in a loop, the message
names the input; for a measured figure, it gives the figure. `try #require` is
for the thing the rest of the test can't run without. The message is a string
literal, with interpolation; the macro takes a `Comment`, so a concatenated
`String` doesn't compile.

**Incorrect:**

```swift
for y in 0..<height {
    #expect(decoded.rgba[transparentIdx + 3] == 0)          // which row?
}
#expect(brightest < 128, "too bright: " + String(brightest)) // doesn't compile
```

**Correct:**

```swift
for y in 0..<height {
    #expect(decoded.rgba[transparentIdx + 3] == 0, "row \(y) left should stay transparent")
}
#expect(brightest < 128, "light squares drew at \(brightest)/255")
let decoded = try #require(DecodedImage(pngData: result.pngData))
```
