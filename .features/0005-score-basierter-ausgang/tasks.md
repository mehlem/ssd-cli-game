---
id: TASKS-0005
feature: "0005-score-basierter-ausgang"
title: "Score Basierter Ausgang"
type: tasks
schema_version: 2
profile: lite
status: completed
phase: implement
created: 2026-06-29
updated: 2026-06-29
related:
  spec: SPEC-0005
  review: REVIEW-0005
tags: []
---

# Tasks: Score Basierter Ausgang

## Approach

- In `show_summary()` eine if/else-Verzweigung auf `score > 6` einbauen: Erfolgstext bei 7/7, Ermutigungs-Text sonst. Score-Anzeige und Phasenliste bleiben in beiden Pfaden erhalten.

## T-001: Score-abhängigen Text in show_summary() einbauen

> Status: completed
> Phase: PH-01
> Implements: ["FR-001", "FR-002", "FR-003", "FR-004"]
> Files: ["game.py (modify)"]

### Description

`show_summary()` verzweigt auf `score > 6`: Erfolgstext (bisherig) oder ermutigenden Text. Score-Zeile und Phasenliste bleiben in beiden Pfaden.

### Done When

- score=7 → Erfolgstext sichtbar.
- score≤6 → ermutigender Text mit SmartFlow sichtbar, kein Erfolgstext.

### Non-Goals

- Keine Änderung an Sterne-Logik, Phasenliste oder `print_centered`-Header.

### Scope Boundary

- In scope: `show_summary()` in `game.py` (Zeile 636–656).
- Out of scope: alles andere.

### Steps

1. In `show_summary()` den `print_box()`-Aufruf in eine `if score > 6 / else`-Verzweigung aufteilen.
2. Erfolgstext (if): bisheriger Inhalt unverändert.
3. Ermutigungstext (else): neuer Text mit SmartFlow-Referenz und Einladung zur Wiederholung.

### Acceptance Criteria

- [x] AC-001: show_summary(7, 7) → Ausgabe enthält "Du hast das SmartFlow-Projekt gerettet".
- [x] AC-002: show_summary(6, 7) → Ausgabe enthält NICHT "gerettet", enthält "SmartFlow".
- [x] AC-003: show_summary(0, 7) → Ausgabe enthält "SmartFlow", kein "gerettet".
- [x] AC-004: Beide Pfade enthalten "von 7".

### Verification

```bash
py -c "
import io, sys
from game import show_summary

def capture(score, total):
    sys.stdout = io.StringIO()
    try: show_summary(score, total)
    except: pass
    out = sys.stdout.getvalue()
    sys.stdout = sys.__stdout__
    return out

o7 = capture(7, 7)
o6 = capture(6, 7)
o0 = capture(0, 7)
assert 'SmartFlow-Projekt gerettet' in o7, 'AC-001 FAIL'
assert 'SmartFlow-Projekt gerettet' not in o6, 'AC-002 FAIL: Erfolgstext bei score=6'
assert 'SmartFlow' in o6, 'AC-002 FAIL: kein SmartFlow bei score=6'
assert 'SmartFlow-Projekt gerettet' not in o0, 'AC-003 FAIL'
assert 'von 7' in o7 and 'von 7' in o6, 'AC-004 FAIL'
print('OK - alle ACs bestanden')
"
```
