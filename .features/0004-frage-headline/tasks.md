---
id: TASKS-0004
feature: "0004-frage-headline"
title: "Frage Headline"
type: tasks
schema_version: 2
profile: lite
status: completed
phase: implement
created: 2026-06-29
updated: 2026-06-29
related:
  spec: SPEC-0004
  review: REVIEW-0004
tags: []
---

# Tasks: Frage Headline

## Approach

- In `ask_question()` den `print_box()`-Aufruf erweitern: Headline als erste Zeile, Leerzeile, dann Fragetext.

## T-001: Headline in Fragen-Box einfügen

> Status: completed
> Phase: PH-01
> Implements: ["FR-001"]
> Files: ["game.py (modify)"]

### Description

`ask_question()` in `game.py` erhält die Headline "Hier eine Verständnisfrage zur Arbeit mit SDD" als erste Zeile in `print_box()`.

### Done When

- Die Fragen-Box jeder Phase zeigt die Headline als erste Zeile.

### Non-Goals

- Keine Änderung an Fragetext, Optionen oder Feedback.

### Scope Boundary

- In scope: `ask_question()` in `game.py` — nur der `print_box()`-Aufruf.
- Out of scope: alles andere.

### Steps

1. In `ask_question()` den `print_box([q["frage"]])` Aufruf zu `print_box(["Hier eine Verständnisfrage zur Arbeit mit SDD", "", q["frage"]])` ändern.

### Acceptance Criteria

- [x] AC-001: Erste Zeile der Fragen-Box lautet exakt "Hier eine Verständnisfrage zur Arbeit mit SDD".

### Verification

```bash
py -c "from game import PHASES, ask_question; import io, sys; sys.stdout = io.StringIO(); [exec('try:\\n ask_question(PHASES[0][\"interaktion\"])\\nexcept: pass')]; out = sys.stdout.getvalue(); sys.stdout = sys.__stdout__; assert 'Hier eine Verständnisfrage' in out, 'Headline fehlt'; print('OK')"
```
