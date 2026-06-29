---
id: CONT-0002
feature: "0002-sdd-cli-game-interactive"
title: "Sdd Cli Game Interactive"
type: continuity
schema_version: 2
# status: active | completed | abandoned | superseded
# Detection treats completed/abandoned/superseded as inactive — set explicitly
# when a feature is replaced (add `superseded_by:`) or dropped.
status: completed
created: 2026-06-26
updated: 2026-06-26
related:
  brief: BRIEF-0002
  spec: SPEC-0002
  research: RESEARCH-0002
  plan: PLAN-0002
  tasks: TASKS-0002
  review: REVIEW-0002
  scratchpad: SCRATCH-0002
  knowledge: KB-0002
tags: []
---

# Continuity: Sdd Cli Game Interactive

## Goal

Interaktive Spielelemente für das SDD CLI Game — Multiple-Choice, Entscheidungen und Feedback pro Phase

## Constraints / Assumptions

- Erweitert `game.py` aus 0001 — kein Neuschreiben
- Python 3 stdlib only, kein externes Paket
- `interaktion`-Feld in PHASES-Dict (AD-001)
- `ask_question(q)` typ-dispatched, gibt 0/1 zurück (AD-002)
- Markdown-Frage in Design-Phase (AD-005)

## Key Decisions

- AD-001: `interaktion`-Feld direkt im PHASES-Dict
- AD-002: `ask_question(q)` — neue Funktion, typ-dispatched
- AD-003: Schema `{typ, frage, optionen, richtig, feedback_richtig, feedback_falsch}`
- AD-004: `run_phase()` → `int`, `main()` akkumuliert Score
- AD-005: Markdown-Frage in Design-Phase (Phase 2)

## State

<!-- SDD-AUTO-START -->
### Done

- T-001: `ask_question()`, PHASES-Schema, `run_phase()`→int, `show_summary(score,total)`, `main()` Score — Verifikation bestanden

### Now

- T-002 als nächstes (blocked für Session-Ende): Brief-Phase Interaktionsdaten

### Next

- T-002: Brief — brief.md-Abschnitte-Frage
- T-003: Design — Markdown vs JSON/XML
- T-004: Research + Plan
- T-005: Implement + Review + Close

### Working Set

- `game.py` — aktive Implementierungsdatei
<!-- SDD-AUTO-END -->

## Open Questions

- (keine)

## Reasoning State

### Active Assumptions

- `dict(_SKELETON)` erzeugt je Phase eine eigene Dict-Kopie (shallow copy reicht für String-Felder)

### Open Ambiguity

- (keine)

### Current Blocker

- (kein Blocker — T-002 blocked für sauberes Session-Ende)

### Next Verification Target

```
py -c "import game; q = game.PHASES[0]['interaktion']; assert 'brief.md' in q['frage']; assert 'In SDD' in q['feedback_richtig']; print('T-002 OK')"
```

### Active Scope Boundary

- T-002 in scope: `PHASES[0]['interaktion']` in `game.py`
- Out of scope: alle anderen PHASES-Einträge
