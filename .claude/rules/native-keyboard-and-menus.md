---
title: The Shortcuts and Menus Every Mac User Knows
impact: HIGH
impactDescription: An invented shortcut is one the user has to learn; a missing menu item is one they cannot find
tags: [native, macos, keyboard, shortcuts, menus]
paths: ["ImageAlphaApp.swift", "ImageAlphaDocument.swift", "Views/**/*.swift"]
---

## The Shortcuts and Menus Every Mac User Knows

**Impact: HIGH**

The menu bar is built by hand in `AppDelegate.buildMainMenu()`, in the
standard order — ImageAlpha, File, Edit, View, Tools, Window, Help — and the
common actions carry the platform's shortcut:

| Action | Shortcut |
|---|---|
| New, Open…, Close | ⌘N, ⌘O, ⌘W |
| Save…, Save As… | ⌘S, ⇧⌘S |
| Undo, Redo, Cut, Copy, Paste, Select All | ⌘Z, ⇧⌘Z, ⌘X, ⌘C, ⌘V, ⌘A |
| Zoom In, Zoom Out | ⌘+, ⌘- |
| Minimise, Hide, Hide Others, Quit | ⌘M, ⌘H, ⌥⌘H, ⌘Q |
| ImageAlpha Help | ⌘? |
| Show original (sidebar toggle) | Space |

Tools holds the app-wide defaults (Dithering, Quality), which write the user's
preferences; the sidebar changes only the open document. A new action takes the
shortcut Apple's guidelines give it, or none, and goes in the menu where it
belongs; a shortcut Apple has assigned is never given a second meaning.

AppKit adds some items itself: Open Recent after Open…, the window list in
Window, Enter Full Screen and the tab items in View. A hand-built copy appears
twice — the hand-built Open Recent did, until it was taken out. Check a menu in
the running app after changing it.

**Incorrect (a second Open Recent; a shortcut with a meaning of its own):**

```swift
fileMenu.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "")
toolsMenu.addItem(withTitle: "Quantize Again", action: #selector(requantize(_:)), keyEquivalent: "r")
```

**Correct:**

```swift
fileMenu.addItem(withTitle: "Open…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
// No Open Recent here: AppKit inserts its own after Open…
```

Reference: Apple Human Interface Guidelines, Keyboard and Menus — the
conventions are in the WWDC design talks and AppKit's docs (see the
`apple-docs` skill).
