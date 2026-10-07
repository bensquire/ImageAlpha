---
title: A Change Is Checked, Not Believed
impact: CRITICAL
impactDescription: CI builds Release and lints the whole tree; a change checked only in Debug, on one file, can still break it
tags: [workflow, verification, tests, lint, build]
paths: ["*.swift", "Views/**", "ImageAlphaTests/**", "Makefile", "*.xcconfig", "ImageAlpha.xcodeproj/**", "Info.plist"]
---

## A Change Is Checked, Not Believed

**Impact: CRITICAL**

Before saying a change is done:

1. **`make lint`** — `swift format lint --strict` over the whole tree, as CI and the pre-commit hook run it.
   The edit hooks format and lint each file as it changes; this catches the
   rest.
2. **`make test`**, the whole suite: 100 tests in 9 suites, 6–10 s warm.
   It builds libimagequant first.
3. **`make release`** when the change touches build settings, an xcconfig, the
   bridging header or the C calls. CI builds Release, and `-Osize`, stripping
   and dead-code removal only apply there.
4. **The real thing**, for anything touching quantization, encoding, saving,
   the canvas, drag and drop or the menus: drive the rebuilt app with the
   run-imagealpha skill on a copy of `samples/dice.png`, and check the output
   it wrote — colour type 3 (indexed) in the PNG, the status bar's figures, a
   screenshot. Quit ImageOptim before comparing file sizes, since it rewrites
   saved files.

Report what was run and what it showed. A check that was skipped is named as
skipped, not left out.

**Incorrect (one suite, no lint, no app):**

```
Ran QuantizerTests; passes. Done.
```

**Correct:**

```
make lint clean (25 files); make test: 100 tests in 9 suites pass; make
release builds. Opened a copy of dice.png with the driver, turned Dithered on
and overwrote it: colour type 3, and the screenshot shows the dithered result.
```
