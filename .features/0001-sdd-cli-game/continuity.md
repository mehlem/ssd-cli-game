---
id: CONT-0001
feature: "0001-sdd-cli-game"
title: "Sdd Cli Game"
type: continuity
schema_version: 2
# status: active | completed | abandoned | superseded
# Detection treats completed/abandoned/superseded as inactive — set explicitly
# when a feature is replaced (add `superseded_by:`) or dropped.
status: completed
created: 2026-06-26
updated: 2026-06-26
related:
  brief: BRIEF-0001
  spec: SPEC-0001
  research: RESEARCH-0001
  plan: PLAN-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  knowledge: KB-0001
tags: []
---

# Continuity: Sdd Cli Game

## Goal

Grafisches CLI-Spiel das die SDD-Phasen spielerisch demonstriert

## Constraints / Assumptions

- Python 3 stdlib only, keine externen Pakete
- `curses` nicht verfügbar auf Windows — ANSI-Escape-Codes + `print()`/`input()` stattdessen
- Einzelne Datei `game.py`, kein Package (AD-001)
- Zielplattform: Windows Terminal + Unix-kompatibel
- Simulated world: keine echten `sdd`-Befehle

## Key Decisions

- AD-001: Einzelne Datei `game.py` — maximale Portabilität
- AD-002: ANSI-Konstanten (`GRÜN`, `ROT`, `GELB`, `BLAU`, `CYAN`, `FETT`, `RESET`) am Dateianfang
- AD-003: Lineares `input()`-Modell, kein plattformspezifisches Keyboard-Handling
- AD-004: `PHASES` als Liste von 7 Dicts mit `name`, `zweck`, `kernfrage`, `prompt`
- AD-005: Skip-Intro via `.sdd_game_seen`-Marker relativ zu `__file__`

## State

<!-- SDD-AUTO-START -->
### Done

- T-001 bis T-007: Alle Tasks abgeschlossen, alle Verifikationen bestanden
- Spec-Reviewer: PASS — alle 7 ACs erfüllt (2 Minor-Findings: sys-Import ungenutzt, ANSI ohne Fallback)

### Now

- Review-Phase läuft: Quality-Reviewer noch ausstehend (im Hintergrund)
- Nach Eingang: review.md befüllen und Verdict auf pass setzen

### Next

- Close-Phase nach positivem Review-Verdict

### Working Set

- `game.py` — aktive Implementierungsdatei
- `.features/0001-sdd-cli-game/tasks.md` — Task-Referenz
<!-- SDD-AUTO-END -->

## Open Questions

- HYP-001 noch unbestätigt: ANSI-Farben im Windows Terminal — beim ersten manuellen `py game.py`-Aufruf prüfen

## Reasoning State

### Active Assumptions

- `py`-Launcher ist auf Zielmaschinen verfügbar (FC-002 bestätigt für Entwicklungsmaschine)
- ANSI-Codes funktionieren im Windows Terminal (HYP-001, noch nicht manuell geprüft)

### Open Ambiguity

- (keine blockierenden Unklarheiten)

### Current Blocker

- (kein Blocker)

### Next Verification Target

```
py -c "import game; src = open('game.py').read(); assert callable(game.show_intro), 'show_intro fehlt'; assert 'PTA' in src; assert 'ibe' in src; print('T-002 OK')"
```

### Active Scope Boundary

- T-002 in scope: `show_intro()` in `game.py`
- T-002 out of scope: Skip-Marker, `main()`-Dispatch, Phasen-Content
