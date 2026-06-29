---
id: TASKS-0008
feature: "0008-intro-ux-verbesserung"
title: "Intro Ux Verbesserung"
type: tasks
schema_version: 2
profile: lite
status: completed
phase: implement
created: 2026-06-29
updated: 2026-06-29
related:
  spec: SPEC-0008
  review: REVIEW-0008
tags: []
---

# Tasks: Intro UX Verbesserung

## Approach

- T-001: `time.sleep(4)` in `show_intro()` durch Animations-Loop ersetzen.
- T-002: `pause()` um "[x für Ende]" und sys.exit erweitern; Titelseite bekommt eigenen Pause-Text.

## T-001: Loading-Animation unter ASCII-Art Banner

> Status: completed
> Phase: PH-01
> Implements: ["FR-001"]
> Files: ["game.py (modify)"]

### Description

In `show_intro()` wird `time.sleep(4)` durch eine Schleife ersetzt, die "loading.", "loading..", "loading..." animiert anzeigt und insgesamt ~4 Sekunden wartet.

### Done When

- Unter dem Banner erscheint eine animierte loading-Zeile während der Wartezeit.

### Non-Goals

- Keine Änderung an `_print_banner()`.

### Scope Boundary

- In scope: `show_intro()` in `game.py`, nur die Banner-Wartezeit (Zeile 203).
- Out of scope: alles andere.

### Acceptance Criteria

- [x] AC-001: Nach Spielstart erscheint unter dem Banner eine Zeile mit "loading" und Punkten.

### Verification

```bash
py -c "import inspect, game; src = inspect.getsource(game.show_intro); assert 'loading' in src, 'FAIL: loading-Animation fehlt'; print('OK')"
```

---

## T-002: Exit-Option in pause() + Titelseiten-Text

> Status: completed
> Phase: PH-02
> Implements: ["FR-002", "FR-003", "FR-004"]
> Depends-on: ["T-001"]
> Files: ["game.py (modify)"]

### Description

`pause()` erhält "[x für Ende]" im Standardtext und beendet das Spiel bei Eingabe "x". Die Titelseiten-Pause bekommt einen eigenen Text "[ Enter drücken um zu starten ]".

### Done When

- `pause()` Standard-Nachricht enthält "[x für Ende]".
- Bei Eingabe "x" in einer Pause wird `sys.exit(0)` aufgerufen.
- Titelseite zeigt "zu starten" statt "fortzufahren".

### Non-Goals

- Kein Schließen des Terminalfensters — nur Prozess-Exit.

### Scope Boundary

- In scope: `pause()` (Zeile 78) + Titelseiten-`pause()`-Aufruf in `show_intro()` (Zeile 213).
- Out of scope: alle anderen Stellen.

### Acceptance Criteria

- [x] AC-002: `inspect.getsource(show_intro)` enthält "zu starten".
- [x] AC-003: `inspect.getsource(pause)` enthält "[x für Ende]".
- [x] AC-004: `inspect.getsource(pause)` enthält sys.exit.

### Verification

```bash
py -c "
import inspect, game
src_pause = inspect.getsource(game.pause)
src_intro = inspect.getsource(game.show_intro)
assert 'x für Ende' in src_pause, 'FAIL: x für Ende fehlt in pause()'
assert 'sys.exit' in src_pause, 'FAIL: sys.exit fehlt in pause()'
assert 'zu starten' in src_intro, 'FAIL: zu starten fehlt in show_intro()'
print('OK')
"
```
