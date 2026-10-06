---
name: apple-docs
description: Look up Apple's developer documentation, WWDC transcripts and sample code offline with `scrapple`, before using a system API, choosing a system feature, or claiming what macOS does. Use whenever a change touches AppKit, SwiftUI, NSDocument, ImageIO, Core Graphics, Accelerate (vImage), Compression, drag and drop, accessibility or a Human Interface Guideline.
---

# Apple's documentation, locally

`scrapple` (Homebrew, `/opt/homebrew/bin/scrapple`) keeps Apple's developer
documentation, WWDC transcripts, sample projects and their source files in a
local SQLite index at `~/.local/share/scrapple/`, about 300,000 pages in all.
Nothing leaves the machine. It backs the `native-check-apples-documentation`
rule.

## When to ask it

- **Before calling an API** whose signature, default, availability or
  behaviour you aren't certain of. Don't guess what a modifier is called or
  what it does; look it up.
- **Before building anything the system might already provide**, such as a
  panel, a menu item or a drop handler. Search first; the answer is usually in
  a framework the app already links.
- **Before stating a convention as fact**, such as a shortcut, a menu order or
  a window behaviour. The Human Interface Guidelines themselves aren't in the
  index (it covers `/documentation`, not `/design`). Their conventions are in
  the WWDC design talks (search `--type talk`) and in the discussion sections of
  the framework docs.
- **When a doc says one thing and the app does another:** read the doc, then
  decide.

## Commands

```sh
scrapple search "<query>" --type doc  --limit 5 --human    # API reference and articles
scrapple search "<query>" --type talk --limit 5 --human    # WWDC transcripts, with timestamps
scrapple search "<query>" --type sample --limit 3 --human  # sample projects
scrapple search "<query>" --type code_file --limit 3 --human   # a file inside a sample
scrapple -h show /documentation/appkit/nsdocument/fileurl  # the full page as Markdown
scrapple -h show <id>         # a talk or sample, by the id a JSON search returns
scrapple status               # how much is indexed, and what failed
```

- **Output format:** without `--human` (`-h`, before the subcommand for
  `show`) the output is JSON. A search gives `id`, `title`, `type`, `url`,
  `snippet` and `score`. Use JSON when a script reads it, and `-h` when you do.
- **Queries:** a symbol name is the best query (`draggingSourceOperationMask`,
  `NSFilePromiseReceiver`, `vImageBuffer_InitWithCGImage`). A question in words
  works too, because the search is keyword and semantic together.
  - `--keyword-only` is exact and fast for a known name.
  - `--semantic-only` is for a concept you can't name.
  - A dot in a `--keyword-only` query (`NSDocument.SaveOperationType`)
    crashes the search with `fts5: syntax error`. Use the separate words instead.
- **Long pages:** `show` prints the whole page. Pipe it through
  `sed -n '/^# /,/^## See Also/p'` for just the body, or `grep -n` for the part
  you want.
- **`scrapple sync`** refreshes the index. It takes hours from empty, so the
  user runs it, not you.

## When the index says nothing

The index has every page, but some pages are only a declaration. Look further,
in this order:

1. **The SDK headers.** They often carry the detail the page leaves out.
   Grep `$(xcrun --show-sdk-path)/System/Library/Frameworks/AppKit.framework/Headers/`.
   That's where these turned up:
   - `allowedTouchTypes` defaults to direct touches only (NSView.h).
   - `save(_:)` "merely invokes" `saveDocumentWithDelegate:…`, and so does the
     close sheet's Save (NSDocument.h).
   - A nil rect for `cgImage(forProposedRect:…)` means the image's own size
     (NSImage.h).
2. **The running app.** Use `/run-imagealpha`. The menu items AppKit adds by
   itself (Open Recent, Enter Full Screen, the window list) are documented
   nowhere, but they're visible there.
3. **If neither settles it,** say so, and say what the decision rests on.

## What to do with the answer

- **Use the documented API** at its documented signature.
- **Cite the page** where a decision rests on it: one short comment with the
  page's path, e.g.
  `// "may be nil, in which case the sender should present an app-modal panel." /documentation/appkit/nsdocument/windowforsheet`.
  Cite a header as `NSDocument.h, saveDocument:`. A quote and a path are fine;
  a paragraph is not.
- **When a doc contradicts a rule in `.claude/rules/`,** raise it with the
  user. The doc is the platform's word, the rule is the project's, and only the
  user can change the rule.
