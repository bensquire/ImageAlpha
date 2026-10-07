---
title: Messages to the User Are Plain Language
impact: MEDIUM
impactDescription: The reader gets what they need, can find it, understand it and use it — ISO 24495-1:2023
tags: [communication, plain-language, iso-24495]
---

## Messages to the User Are Plain Language

**Impact: MEDIUM**

Messages follow ISO 24495-1:2023's four principles: the reader gets what they
need, can find it, can understand it, and can use it.

- **Lead with what matters.** The outcome or the answer first; the reasoning
  after. If something failed, say so in the first line.
- **Make it findable.** Headings and short lists when a message has more than
  one part. One idea per paragraph.
- **Make it understandable.** Short sentences. Everyday words where they will
  do; a term of art only where it is the precise one, defined the first time.
  Active voice: say who did what.
- **Make it usable.** Numbers carry their unit and what they are compared with.
  End with what the reader can do next, or that nothing is needed. Put a caveat
  where it will be read, not at the bottom.
- **Say what was done, not what was intended.** A test that was not run was not
  run. A check skipped is named as skipped. A file that was overwritten by
  accident is reported in the first line.

**Incorrect:**

```
I've made some improvements to encoding which should help with file sizes;
there may be some edge cases but overall it's better.
```

**Correct:**

```
Saved files are smaller now: the save path re-encodes with libz at level 9,
2–7 % smaller than the preview's encode on large images. The status line
shows the smaller size once that encode finishes, which starts 400 ms after
you stop moving a slider. Nothing is committed.
```

Reference: ISO 24495-1:2023, Plain language — Part 1: Governing principles and guidelines.
