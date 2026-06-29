---
id: RESEARCH-0007
feature: "0007-zweites-frageset-shuffle"
title: "Zweites Frageset Shuffle"
type: research
schema_version: 2
status: completed
phase: research
created: 2026-06-29
updated: 2026-06-29
source: SPEC-0007
links: {"derived_from":["SPEC-0007"],"informed_by":[],"supersedes":[]}
based_on: {"SPEC-0007":"sha256:bfef0839dfa4db9a42a41dea6f42bcaf0a4d9be967e17f8ea65925a957d25cd3"}
related:
  brief: BRIEF-0007
  spec: SPEC-0007
  plan: PLAN-0007
  tasks: TASKS-0007
  review: REVIEW-0007
  scratchpad: SCRATCH-0007
  continuity: CONT-0007
  knowledge: KB-0007
tags: []
---

# Research: Zweites Frageset Shuffle

## Summary

Alle Änderungen liegen in einer einzigen Datei `game.py`. Die `PHASES`-Liste (7 Dicts) hat pro Phase genau ein `interaktion`-Dict. Dieses Feature erweitert jede Phase um ein zweites alternatives `interaktion`-Dict und führt Shuffle-Logik beim Spielstart ein. Der kritische Befund: `q["richtig"]` ist ein 1-basierter Positions-String ("1"–"4"), nicht der Antworttext. Shuffle muss `richtig` nach dem Mischen neu berechnen. `random` ist bereits importiert. Änderungsumfang: moderat — Datenerweiterung (14 neue Felder × 5 Keys) + neue Shuffle-Funktion + Aufruf-Anpassung.

## Facts

- FC-001: `import random` existiert in `game.py:12`. Das Modul ist verfügbar. / Evidence: `game.py:12`.
- FC-002: `PHASES` ist eine Liste von 7 Dicts (`game.py:330`). Jedes Dict hat genau ein `interaktion`-Feld. Kein zweites Fragenset existiert. / Evidence: `game.py:330–602`.
- FC-003: `interaktion`-Dict-Schema: `typ`, `frage`, `optionen` (Liste von 4 Strings), `richtig` (1-basierter Positions-String z.B. "1"), `feedback_richtig`, `feedback_falsch`. / Evidence: `game.py:336–358`.
- FC-004: `ask_question(q)` (`game.py:300`) vergleicht Nutzereingabe mit `q["richtig"]` als String-Vergleich (`game.py:313`). Bei falscher Antwort berechnet es den korrekten Text via `q["optionen"][int(q["richtig"]) - 1]` (`game.py:319`). **Beide Stellen nutzen `richtig` als Positionsindex.** / Evidence: `game.py:307–323`.
- FC-005: `run_phase(phase)` (`game.py:609`) ruft `ask_question(phase["interaktion"])` direkt auf — übergibt das interaktion-Dict unvermittelt. / Evidence: `game.py:627`.
- FC-006: `main()` (`game.py:692`) iteriert `for phase in PHASES` linear — keine Indizes, keine Zufallslogik. Score wird direkt akkumuliert. / Evidence: `game.py:692–697`.
- FC-007: Keine Testdatei vorhanden. Verifikation nur manuell oder per Python-Assertion. / Evidence: Glob `test*.py` → keine Treffer (aus 0003 bekannt).

## Hypotheses

(none)

## Unknowns

(none)

## Affected Files

| File | Action | Module | Impact | Relates To |
|:-----|:-------|:-------|:-------|:-----------|
| `game.py` | modify | main | local | FR-001, FR-002, FR-003, FR-004, FR-005, FR-006 |

## Code Context

### Entry Points

| Entry Point | File | Signature | Change |
|:------------|:-----|:----------|:-------|
| `PHASES` | `game.py:330` | Liste von 7 Dicts | Jedes Dict erhält zweites `interaktion`-Dict (oder Liste von zwei) |
| `run_phase` | `game.py:609` | `run_phase(phase)` | Zufällige Fragenauswahl + Shuffle vor `ask_question()`-Aufruf |
| `ask_question` | `game.py:300` | `ask_question(q)` | Unverändert — empfängt bereits gemischtes Dict |

### Types & Contracts

| Type/Contract | File | Change | Impact |
|:-------------|:-----|:-------|:-------|
| `interaktion`-Dict-Schema | `game.py:336` | PHASES bekommt pro Dict eine Liste `fragen` mit 2 interaktion-Dicts | local |

### Patterns & Conventions

- **Kritisch**: `richtig` ist ein Positions-String, nicht der Antworttext. Nach dem Mischen von `optionen` muss `richtig` neu gesetzt werden. Plan muss entscheiden: (a) Shuffle erstellt eine Kopie des interaktion-Dicts mit aktualisiertem `richtig`, oder (b) `ask_question()` wird refaktoriert um Antworttext statt Index zu vergleichen. Option (a) ist kleinerer Eingriff.
- `run_phase()` hat Zugriff auf `phase`-Dict direkt — Shuffle-Logik kann dort inline eingefügt werden ohne `ask_question()` zu ändern.

## Dependencies

### Internal

| From | To | Type |
|:-----|:---|:-----|
| `run_phase()` | `ask_question()` | call |

### External

| Package/Service | Version | Purpose | New? |
|:----------------|:--------|:--------|:-----|
| `random` | stdlib | Zufällige Auswahl + Shuffle | Nein (bereits importiert) |

## Data Changes

(none — keine DB, keine Datei-Persistenz)

## Configuration

(none)

## Test Landscape

- **Framework**: Keine Tests vorhanden.
- **Verification**: Python-Assertions auf PHASES-Struktur (AC-005) + manuelles Spielen.

## Prior Art

- `random.shuffle()` ist für in-place shuffle; für eine Kopie: `random.sample(liste, len(liste))` oder `liste_kopie = liste[:]; random.shuffle(liste_kopie)`.
- `random.choice()` für zufällige Auswahl eines von zwei interaktion-Dicts.

## System Context

```text
main() → for phase in PHASES
              → run_phase(phase)
                    → [NEU] wähle zufällig interaktion aus phase["fragen"]
                    → [NEU] mische optionen, berechne neues richtig
                    → ask_question(gemischtes_interaktion_dict)
```

## Risks & Concerns

- **Positions-String-Invariante**: Der gesamte Auswertungs-Code in `ask_question()` setzt voraus, dass `richtig` die korrekte Position in der gemischten `optionen`-Liste ist. Fehler hier führt zu falschen Auswertungen ohne Fehlermeldung. Plan muss Shuffle-Logik sehr sorgfältig spezifizieren.
- **Datenmenge**: 7 Phasen × 1 neues interaktion-Dict × 5 Felder = 35 neue String-Felder. Fehleranfällig bei manueller Eingabe — Tests oder Python-Assertions zur Validierung empfohlen.

## Confidence

| Dimension | Score | Notes |
|:----------|------:|:------|
| Scope clarity | 20/20 | Genau eine Datei, Einfügestellen klar |
| Pattern familiarity | 17/20 | Positions-String-Invariante ist subtil — Plan muss explizit adressieren |
| Dependency awareness | 20/20 | `random` verfügbar, keine externen Deps |
| Edge cases | 15/20 | Shuffle + Positions-Update ist fehleranfällig — braucht sorgfältige Spec |
| Test strategy | 12/20 | Nur manuelle Verifikation + Python-Assertions |

- **Total**: 84/100
- **Verdict**: GO
