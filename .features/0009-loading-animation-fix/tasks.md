---
id: TASKS-0009
feature: "0009-loading-animation-fix"
title: "Loading Animation Fix"
type: tasks
schema_version: 2
profile: lite
status: completed
phase: implement
created: 2026-06-29
updated: 2026-06-29
related:
  spec: SPEC-0009
  review: REVIEW-0009
tags: []
---

# Tasks: Loading Animation Fix

## Approach

- Zeitbasierte Schleife statt Dot-Liste; Cursor ausblenden/einblenden; BLAU-Farbe.

## T-001: Loading-Animation verbessern

> Status: completed
> Phase: PH-01
> Implements: ["FR-001", "FR-002", "FR-003"]
> Files: ["game.py (modify)"]

### Description

Den Loading-Animation-Block in `show_intro()` ersetzen: zeitbasierte Schleife mit wachsenden Punkten, BLAU-Farbe, Cursor ausblenden während Animation.

### Done When

- Punkte wachsen über 3 hinaus.
- Cursor während Animation unsichtbar.
- Text blau gefärbt.

### Scope Boundary

- In scope: Loading-Animation-Block in `show_intro()` (~5 Zeilen).
- Out of scope: alles andere.

### Acceptance Criteria

- [x] AC-001: `inspect.getsource(show_intro)` enthält `\033[?25l`.
- [x] AC-002: `inspect.getsource(show_intro)` enthält `BLAU`.

### Verification

```bash
py -c "import inspect, game; src = inspect.getsource(game.show_intro); assert '?25l' in src, 'FAIL: Cursor-Hide fehlt'; assert 'BLAU' in src, 'FAIL: BLAU fehlt'; print('OK')"
```
