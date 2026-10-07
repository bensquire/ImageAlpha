---
title: ImageAlpha Rules Index
impact: LOW
impactDescription: About the rules themselves; loads only when a rule is being written
tags: [meta, rules]
paths: [".claude/rules/*.md"]
---

# ImageAlpha Rules

Modular, machine-readable rules for working on ImageAlpha. Each file is one
rule, named `{section}-{rule-name}.md`, with YAML frontmatter Claude Code reads:
a rule with `paths` loads only when a matching file is in play; one without
applies always. `_sections.md` defines the sections and their order;
`_template.md` is the shape of a new rule.

## Rules Index

### Workflow

- [workflow-challenge-the-rules](workflow-challenge-the-rules.md) - A rule in the way is raised with the user, not obeyed or broken in silence
- [workflow-no-commits-unless-told](workflow-no-commits-unless-told.md) - Never commit or push unless told to
- [workflow-hand-over-for-trial](workflow-hand-over-for-trial.md) - Build, relaunch, say what to look at, stop
- [workflow-checking-work](workflow-checking-work.md) - Lint, the whole suite, Release when settings change, then the app on a real PNG
- [workflow-commit-messages](workflow-commit-messages.md) - What and why, with the measurements
- [workflow-diagnostics](workflow-diagnostics.md) - `os.Logger` at debug level to keep, a separate file to throw away
- [workflow-todo-entries](workflow-todo-entries.md) - A short bullet in the local `TODO.md`; the reasoning lives in the commit

### Quality

- [quality-separation-of-concerns](quality-separation-of-concerns.md) - Encoder, quantizer, model, document, views; dependencies run one way
- [quality-dependency-injection](quality-dependency-injection.md) - Options, effort and locale handed in as values; `Preferences` read at the edges
- [quality-readability](quality-readability.md) - Code reads like the prose around it
- [quality-consistency](quality-consistency.md) - Match the code around you; reuse the helper that exists
- [quality-extensible](quality-extensible.md) - Add a case and its behaviour, not an `if`
- [quality-performant](quality-performant.md) - Debounced, cancellable, measured on a large image
- [quality-secure](quality-secure.md) - Sandboxed; offline; nothing overwritten without asking
- [quality-comments-carry-measurements](quality-comments-carry-measurements.md) - Short, says why, carries the number or the doc path
- [quality-formatting-is-the-tools](quality-formatting-is-the-tools.md) - swift-format decides, at the toolchain's version
- [quality-images-minified](quality-images-minified.md) - Lossless first, then quantized to the edge, judged at 1:1; test input untouched

### Testing

- [testing-arrange-act-assert](testing-arrange-act-assert.md) - Each step present, in order, marked
- [testing-one-behaviour-per-test](testing-one-behaviour-per-test.md) - One behaviour, named as a sentence
- [testing-ground-truth-with-teeth](testing-ground-truth-with-teeth.md) - Judge the decoded PNG; say what the alternative measures
- [testing-deterministic](testing-deterministic.md) - Generated fixtures, own temp dirs, isolated preferences, no waiting for luck
- [testing-fast](testing-fast.md) - Fast by paying only for what the test needs, never by seeing less
- [testing-failure-reads-as-a-sentence](testing-failure-reads-as-a-sentence.md) - A message where the expression alone doesn't tell the story

### Native

- [native-use-the-systems-feature](native-use-the-systems-feature.md) - NSDocument, sheets, file promises, vImage; a hand-built part says why
- [native-keyboard-and-menus](native-keyboard-and-menus.md) - The shortcuts every Mac user knows; nothing AppKit already adds
- [native-small-bundle](native-small-bundle.md) - About 1.3 MB, no frameworks of its own
- [native-check-apples-documentation](native-check-apples-documentation.md) - Look it up in `scrapple` before using, copying or asserting

### Communication

- [communication-plain-language](communication-plain-language.md) - ISO 24495-1: relevant, findable, understandable, usable
