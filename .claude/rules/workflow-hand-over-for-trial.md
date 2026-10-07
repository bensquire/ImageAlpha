---
title: Hand Work Over for the User to Try
impact: CRITICAL
impactDescription: The user judges a feature in the app, not in a report
tags: [workflow, handover, build, app]
---

## Hand Work Over for the User to Try

**Impact: CRITICAL**

When a change the user can see in the app is done and checked, put it in front
of them there. A change to the tests, the rules or the docs is handed over as
what it is: the suite's result, the file to read.

1. `.claude/skills/run-imagealpha/driver.sh build`, so the Debug app carries
   the change (ad-hoc signed and sandboxed, like a release; `make debug` needs
   a development team and fails without one).
2. Relaunch it: `driver.sh launch`, with a fresh copy of the image the trial
   needs (`driver.sh fixture` copies `samples/dice.png`). Documents start from
   the file; the preferences in `Preferences.Key` persist, in the container
   `CLAUDE.md` names and shared with any installed copy, so say which the trial
   assumes. If ImageOptim is installed, saving hands the file to it.
3. Say what to look at and what the figures were.
4. Stop.

**Incorrect (declaring done from the command line):**

```
The suite passes and the drag-out test writes dice-quantized.png. Done.
```

**Correct (the app relaunched, the eye pointed):**

```
Rebuilt and relaunched with a copy of dice.png open. Drag the image to the
Desktop: the file should be dice-quantized.png, and a second drag to the same
place should leave the first file as it is.
```
