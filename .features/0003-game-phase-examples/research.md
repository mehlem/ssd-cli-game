---
id: RESEARCH-0003
feature: "0003-game-phase-examples"
title: "Game Phase Examples"
type: research
schema_version: 2
status: completed
phase: research
created: 2026-06-29
updated: 2026-06-29
source: SPEC-0003
links: {"derived_from":["SPEC-0003"],"informed_by":[],"supersedes":[]}
based_on: {"SPEC-0003":"sha256:d22b1e33fde5bc0d3b1e7b043734e8dc03607ee16f44a6db9d2d0546ae5abe66"}
related:
  brief: BRIEF-0003
  spec: SPEC-0003
  plan: PLAN-0003
  tasks: TASKS-0003
  review: REVIEW-0003
  scratchpad: SCRATCH-0003
  continuity: CONT-0003
  knowledge: KB-0003
tags: []
---

# Research: Game Phase Examples

## Summary

Die gesamte Spiellogik liegt in einer einzigen Datei `game.py`. Die `PHASES`-Liste (Zeilen 330–560) enthält 7 Dicts, die `run_phase()`-Funktion (Zeilen 567–588) rendert jede Phase. Das neue Beispiel-Panel wird zwischen Kernfrage-Ausgabe und `ask_question()`-Aufruf eingefügt. Der Zurück-Mechanismus (z-Taste, `can_go_back`-Parameter, `phase_scores`-Dict) ist klar abgegrenzt und kann chirurgisch entfernt werden. Keine Tests vorhanden. Änderungsumfang: gering — eine Datei, zwei klar trennbare Eingriffe.

## Facts

- FC-001: `PHASES` ist eine Liste von 7 Dicts, definiert in `game.py:330–560`. Felder je Dict: `name`, `zweck`, `kernfrage`, `prompt`, `interaktion` (mit `typ`, `frage`, `optionen`, `richtig`, `feedback_richtig`, `feedback_falsch`). Kein `beispiel`-Feld existiert. / Evidence: `game.py:330–360` (erstes Dict gelesen).
- FC-002: `run_phase(phase, can_go_back=False)` ist definiert in `game.py:567`. Ablauf: `clear_screen()` → Phase-Name-Box → Zweck → Kernfrage → `ask_question()` → Navigation. / Evidence: `game.py:567–588`.
- FC-003: Das Beispiel-Panel muss nach Kernfrage-Ausgabe (Zeile 577) und vor `ask_question()` (Zeile 578) eingefügt werden. / Evidence: `game.py:572–578`.
- FC-004: Der Zurück-Mechanismus besteht aus: (a) `can_go_back`-Parameter in `run_phase()` (`game.py:567`), (b) `if can_go_back:` Block mit z-Taste-Abfrage (`game.py:580–587`), (c) `can_go_back=(i > 0)` Aufruf-Argument (`game.py:655`), (d) `if result is None:` Zurück-Logik mit `phase_scores`-Dict (`game.py:656–661`). / Evidence: `game.py:580–587, 654–661`.
- FC-005: `print_box(lines, color=BLAU)` (`game.py:106–115`) ist die Standard-Funktion für Panel-Rendering. Zeichnet eine Box mit `┌─┐│└─┘`-Rahmen, bricht lange Zeilen um, begrenzt Breite auf `min(terminal_width()-4, 76)`. / Evidence: `game.py:106–115`.
- FC-006: Keine Testdatei für `game.py` vorhanden. / Evidence: Glob `test*.py` ergab keine Treffer.
- FC-007: `ask_question()` (`game.py:300–323`) zeigt Frage, Optionen, nimmt Eingabe entgegen, gibt Feedback aus und ruft `pause()` am Ende auf. Rückgabewert: `1` (richtig) oder `0` (falsch). / Evidence: `game.py:300–323`.
- FC-008: `main()` verwendet `phase_scores`-Dict (`game.py:652`) ausschließlich für die Zurück-Navigation. Nach Entfernung des Zurück-Mechanismus kann es durch eine einfache `score += result`-Akkumulation ersetzt werden. / Evidence: `game.py:651–668`.

## Hypotheses

(none)

## Unknowns

(none)

## Affected Files

| File | Action | Module | Impact | Relates To |
|:-----|:-------|:-------|:-------|:-----------|
| `game.py` | modify | main | local | FR-001, FR-002, FR-003, FR-004, FR-005 |

## Code Context

### Entry Points

| Entry Point | File | Signature | Change |
|:------------|:-----|:----------|:-------|
| `run_phase` | `game.py:567` | `run_phase(phase, can_go_back=False)` | `can_go_back`-Parameter entfernen; Beispiel-Panel vor `ask_question()` einfügen |
| `main` | `game.py:635` | `main()` | `phase_scores`-Dict und Zurück-Logik entfernen; `can_go_back`-Argument entfernen |
| `PHASES` | `game.py:330` | Liste von 7 Dicts | Neues Feld `beispiel` mit 4 Unterfeldern je Dict hinzufügen |

### Types & Contracts

| Type/Contract | File | Change | Impact |
|:-------------|:-----|:-------|:-------|
| `PHASES` Dict-Schema | `game.py:330` | extend (neues Feld `beispiel`) | local |

### Patterns & Conventions

- Panels werden mit `print_box(lines, color=X)` gerendert (`game.py:106`). Neue Panels folgen demselben Muster.
- Farbkonstanten sind global definiert (`game.py:18–29`). Das Beispiel-Panel kann bestehende Farben (GRÜN, CYAN, GELB, GRAU) nutzen — keine neuen Konstanten nötig.
- Emoji-Zeichen werden in Strings direkt verwendet (z.B. `"✓"`, `"★"`). Die 4 Panel-Felder (🧑, 👤, 🤖, 📄) folgen diesem Muster. `_display_len()` (`game.py:93`) behandelt Wide-Zeichen korrekt.

## Dependencies

### Internal

| From | To | Type |
|:-----|:---|:-----|
| `run_phase()` | `print_box()` | import |
| `run_phase()` | `ask_question()` | import |

### External

(none — Python 3 stdlib only, keine neuen Abhängigkeiten)

## Data Changes

(none)

## Configuration

(none)

## Test Landscape

- **Framework**: Keine Tests vorhanden.
- **Verification**: Manueller Start `py game.py`, alle 7 Phasen durchspielen und Beispiel-Panel pro Phase prüfen.
- **Coverage**: 0 % — keine automatisierten Tests.

## Prior Art

- `print_box()` wird bereits für Feedback-Panels, Intro-Szenen und Zusammenfassung genutzt (`game.py:218, 236, 259, 276, 601`). Das Beispiel-Panel folgt demselben Muster.
- Mehrfeldrige Anzeigen: `_print_side_by_side()` (`game.py:178`) zeigt wie zwei Spalten nebeneinander gerendert werden — für das 4-zeilige Beispiel-Panel ist `print_box()` mit Zeilen-Liste die einfachere Lösung.

## System Context

```text
main() → run_phase(phase)
              │
              ├── print_box([phase["name"]])
              ├── print zweck + kernfrage
              ├── [NEU] print_box(beispiel-panel aus phase["beispiel"])
              ├── ask_question(phase["interaktion"])  → score
              └── pause()
```

## Risks & Concerns

- **Zeilenumbruch bei langen Beispieltexten**: `print_box()` bricht bei `w-4` Zeichen um. Einige PO-Texte aus brief.md Q3 sind lang (~120 Zeichen). Das ist kein Problem — `print_box()` handled Umbruch automatisch, aber die Kompaktheit (AC-006) muss beim manuellen Test verifiziert werden.
- **Emoji-Breite**: 🧑, 👤, 🤖, 📄 sind Wide-Zeichen (2 Spalten). `_display_len()` behandelt das korrekt; `print_box()` nutzt allerdings `_display_len()` nicht für Padding-Berechnung. Hypothese: Rahmen-Ausrichtung könnte minimal verschoben sein. Muss im Test beobachtet werden.

## Confidence

| Dimension | Score | Notes |
|:----------|------:|:------|
| Scope clarity | 20/20 | Genau eine Datei, zwei trennbare Eingriffe, Einfügestelle klar |
| Pattern familiarity | 18/20 | `print_box()` bekannt; Emoji-Padding-Verhalten noch unbestätigt |
| Dependency awareness | 20/20 | Keine externen Deps, kein DB, kein Config |
| Edge cases | 15/20 | Emoji-Breite in `print_box()` ist offener Punkt |
| Test strategy | 12/20 | Nur manueller Test möglich — keine automatisierte Verifikation |

- **Total**: 85/100
- **Verdict**: GO
