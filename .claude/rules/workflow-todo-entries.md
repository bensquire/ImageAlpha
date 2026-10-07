---
title: A TODO Entry Is Short
impact: MEDIUM
impactDescription: The TODO is a list to scan, not a place to keep reasoning
tags: [workflow, todo, planning]
paths: ["TODO.md"]
---

## A TODO Entry Is Short

**Impact: MEDIUM**

`TODO.md` at the root is the user's local list of what is left, and it stays
out of commits. Each entry is one bullet: a bold name, then a sentence or two
saying what is left and what would settle it. Entries are grouped under a
heading that says what kind of thing they are, and a thing is never listed
twice.

The reasoning — what was measured, what went wrong, why it was taken out —
lives in the commit that did it and the code that carries it, not here. What
shipped goes in `CHANGELOG.md` at release time.

**Incorrect:**

```
## Promised drops

Photos and Mail offer the image as an NSFilePromiseReceiver … (three
paragraphs on the drag pasteboard, the temporary folder and duplicateDocument)
```

**Correct:**

```
## Not verified end to end

- **Dropping a file promise** (an image dragged from Photos, Mail or a browser).
  Receiving the file and opening it hasn't run, because nothing here can act as
  the drag source.
```
