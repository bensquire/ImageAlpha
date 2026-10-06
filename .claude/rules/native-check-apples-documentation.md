---
title: Check Apple's Documentation Before Using Its API
impact: HIGH
impactDescription: A guessed default compiles and quietly does nothing; an asserted platform fact goes unchecked
tags: [native, documentation, scrapple, apple, hig, wwdc]
paths: ["**/*.swift"]
---

## Check Apple's Documentation Before Using Its API

**Impact: HIGH**

Before using a system API you are not certain of, before building anything the
system might already provide, and before stating a platform fact in a comment,
look it up. `scrapple` holds Apple's framework documentation, WWDC transcripts
and sample code offline. The `apple-docs` skill says how to ask it, and where
to look when a page is only a declaration: the SDK headers, then the running app.

A decision that rests on what a page says carries the page's path in a
one-line comment, so the next reader can check it too. A doc that contradicts a
rule here is raised with the user, not followed or ignored in silence.

**Incorrect (a platform fact, asserted without a source):**

```swift
// ImageIO can only write truecolor PNGs.
```

**Correct (looked up, and the claim cut to what the docs support):**

```sh
scrapple search "PNG image properties" --type doc --limit 3 --human
```

```swift
// Apple documents no way to have ImageIO write a palette: its PNG properties
// have no palette or bit-depth key (/documentation/imageio/png-image-properties).
```

Reference: `scrapple` (github.com/searlsco/scrapple); Apple Developer Documentation.
