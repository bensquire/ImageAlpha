---
title: Formatting Is Decided by the Tools
impact: MEDIUM
impactDescription: No formatting diffs, no style arguments in review, no drift between machines
tags: [quality, formatting, swift-format, hooks, lint]
paths: ["*.swift", "Views/**/*.swift", "ImageAlphaTests/**/*.swift", ".swift-format"]
---

## Formatting Is Decided by the Tools

**Impact: MEDIUM**

swift-format and `.swift-format` (4 spaces, 110 columns, ordered imports) are
the formatting authority and the only linter.

- **As you edit**, the hooks in `.claude/hooks` format each Swift file with
  swift-format and then report any line still over 110 columns. swift-format
  cannot break a long string or comment by itself; reflow what the hook
  reports before handing over. The hooks are advisory so that a formatting
  hiccup never blocks an edit.
- **The whole tree:** `make lint` (`swift format lint --strict`; what CI and
  the pre-commit hook run) and `make format` (swift-format in place).
- **Versions:** swift-format comes with Xcode's toolchain, and CI pins Xcode
  26.6 (swift-format 6.3.0), so a local Xcode 26.6 lints exactly as CI does.
- **Safety rules:** `NeverUseForceTry`, `NeverForceUnwrap` and
  `NeverUseImplicitlyUnwrappedOptionals` are on. Route a nil into the error
  path the code already has (`guard let`, `try`), use `try #require` in tests,
  and give a view's layers their value at declaration rather than `CALayer!`.
  Where a value provably can't be nil, put
  `// swift-format-ignore: NeverForceUnwrap` on the line above with the reason,
  as `helpURL` in `ImageAlphaApp.swift` does.

Leave formatting to the tools rather than hand-formatting around them, and
leave a rule they enforce on rather than disabling it inline, except as the
safety-rules bullet says. One thing
swift-format does that reads oddly at first: a wrapped condition puts its
opening brace on a line of its own. That is the house style.

**Incorrect:**

```swift
// swift-format-ignore
if let toolsMenu = NSApp.mainMenu?.item(withTitle: "Tools")?.submenu, let ditherItem = toolsMenu.item(withTitle: "Dithering"), let ditherMenu = ditherItem.submenu {
```

**Correct:**

```swift
if let toolsMenu = NSApp.mainMenu?.item(withTitle: "Tools")?.submenu,
    let ditherItem = toolsMenu.item(withTitle: "Dithering"),
    let ditherMenu = ditherItem.submenu
{
```
