---
title: Commit Messages Say Why, With the Measurements
impact: HIGH
impactDescription: The history is where the reasoning is kept
tags: [workflow, git, commits, history]
---

## Commit Messages Say Why, With the Measurements

**Impact: HIGH**

When told to commit, the message says what changed and why, with the
measurements that justified it — the image or fixture, the figure before, the
figure after — and what was tried and taken out, if anything was. A commit of
one change is a subject line and a short paragraph; a commit of several lists
them as bullets, each with its reason, as this repo's history does. One commit
per change of meaning: work that was already in the tree and is not part of the
change goes in its own commit, described honestly. End with the attribution
lines the session prescribes.

**Incorrect:**

```
Speed up encoding and misc fixes
```

**Correct:**

```
Speed up PNG encoding 2x and skip stale quantization requests

Benchmarked on a 12MP image: the indexed PNG encoder was the slowest
pipeline phase (990ms), ahead of libimagequant itself (~450ms).

- packScanlines: preallocated buffer + memcpy fast path for 8-bit rows
  instead of per-byte Data.append (410ms -> 2ms)
- Quantizer checks Task cancellation before and during work, so slider
  scrubbing no longer runs every queued quantization to completion
```
