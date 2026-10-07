---
title: Rule Sections
impact: LOW
impactDescription: About the rules themselves; loads only when a rule is being written
tags: [meta, rules]
paths: [".claude/rules/*.md"]
---

# Sections

This file defines all sections, their ordering, impact levels, and descriptions.
The section ID (in parentheses) is the filename prefix used to group rules.

---

## 1. Workflow (workflow)

**Impact:** CRITICAL
**Description:** How work is checked, handed over and committed, and how a rule
that is in the way gets challenged. The rules that decide whether anything else
matters.

## 2. Quality (quality)

**Impact:** HIGH
**Description:** How the Swift is written: separation of concerns, dependency
injection, readability, consistency, extensibility, performance, security,
comments that add value, images kept small, and formatting left to the tools.

## 3. Testing (testing)

**Impact:** HIGH
**Description:** What a test is for and what keeps the suite worth running:
shape, scope, determinism, speed, failure messages, and ground truth in the
decoded PNG.

## 4. Native (native)

**Impact:** HIGH
**Description:** The app feels and works like a Mac app, by using what macOS
provides — and stays small because of it.

## 5. Communication (communication)

**Impact:** MEDIUM
**Description:** How messages to the user are written.
