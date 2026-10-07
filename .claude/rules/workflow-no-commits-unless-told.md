---
title: Never Commit or Push Unless Told To
impact: CRITICAL
impactDescription: A committed feature the user did not want costs a revert and trust
tags: [workflow, git, commits, handover]
---

## Never Commit or Push Unless Told To

**Impact: CRITICAL**

Commit and push only when the user has said to in this conversation. "Make it
work", "fix it" and "finish it" are not that instruction. "Commit", "commit and
push", or a reply that says the work stays, are. When told to commit on
`master`, branch first and say so.

The user tries a feature before deciding whether it stays. A working feature is
not the same as a wanted one, and only they can tell the difference.

This is about product decisions, not about editing: change files without asking
permission. `TODO.md` at the repo root is the exception the other way: it is
the user's local tracker and stays out of commits.

**Incorrect (committing because the work is done):**

```
Tests pass and the drag-out writes the file, so I've committed and pushed.
```

**Correct (handing over and waiting):**

```
Tests pass. I've rebuilt and relaunched ImageAlpha with a copy of dice.png
open — drag the image to the Desktop and check the file's name. Nothing is
committed; say if it stays.
```
