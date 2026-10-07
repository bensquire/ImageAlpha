---
title: Challenge a Rule When It Is in the Way
impact: CRITICAL
impactDescription: The rules serve the best app; a rule that blocks a better one is a defect to raise, not a wall to work around
tags: [workflow, rules, architecture, standards, judgement]
---

## Challenge a Rule When It Is in the Way

**Impact: CRITICAL**

These rules exist to make the best app, not to be obeyed for their own sake.
When following one would make the code, the architecture, a standard or the
product worse — or when a better way exists that a rule forbids — raise it with
the user, plainly: which rule, what it costs here, what the alternative is, and
what it would take. Then wait. Sometimes the answer is to rearchitect, change a
standard, or rewrite the rule.

Complying in silence and breaking the rule in silence both hide the decision,
so do neither. A rule the user has just confirmed stands.

**Incorrect (working around it, or working under it in silence):**

```
"Use the system's feature" says ImageIO writes the PNG, so saves now go through
CGImageDestination.
```

**Correct (the case made, the decision left with the user):**

```
"Use the system's feature" and the point of the app collide: ImageIO documents
no way to write a palette (/documentation/imageio/png-image-properties has no
palette or bit-depth key), so its files come out truecolor and lose what
quantizing bought. Keeping indexed output means an encoder of our own: IHDR,
PLTE, tRNS and IDAT, with deflate from Compression. Want that, or truecolor
through ImageIO?
```
