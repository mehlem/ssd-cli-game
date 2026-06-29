---
id: RESEARCH-0002
feature: "0002-sdd-cli-game-interactive"
title: "Sdd Cli Game Interactive"
type: research
schema_version: 2
status: completed
phase: research
created: 2026-06-26
updated: 2026-06-26
source: SPEC-0002
links: {"derived_from":["SPEC-0002"],"informed_by":[],"supersedes":[]}
based_on: {"SPEC-0002":"sha256:43494389d026bf276c7fe5bc24db5cc1b828e89fea29b48acb3d77d218345176"}
related:
  brief: BRIEF-0002
  spec: SPEC-0002
  plan: PLAN-0002
  tasks: TASKS-0002
  review: REVIEW-0002
  scratchpad: SCRATCH-0002
  continuity: CONT-0002
  knowledge: KB-0002
tags: []
---

# Research: Sdd Cli Game Interactive

## Summary

`game.py` aus Feature 0001 vollständig gelesen. Die interaktiven Erweiterungen betreffen drei Stellen: `PHASES`-Datenstruktur (neues `interaktion`-Feld je Phase), `run_phase()` (ruft neue Interaktionsfunktion auf und gibt Score zurück), `show_summary()` (zeigt Score an) und `main()` (akkumuliert Score). Alle anderen Funktionen (`clear_screen`, `pause`, `print_box`, `print_centered`, `_visible_len`, `show_intro`) bleiben unverändert. Scope ist klar und überschaubar.

## Facts

- FC-001 (confirmed): `PHASES` ist eine Liste von 7 Dicts bei `game.py:179-222`. Jedes Dict hat genau 4 Schlüssel: `name`, `zweck`, `kernfrage`, `prompt`. Evidence: `game.py:180-221` gelesen.
- FC-002 (confirmed): `run_phase(phase)` bei `game.py:229-241` nimmt ein Phase-Dict, hat keine Rückgabe (`None`), endet mit `pause()`. Eine Score-Rückgabe erfordert eine Signaturänderung. Evidence: `game.py:229-241` gelesen.
- FC-003 (confirmed): `show_summary()` bei `game.py:248-265` hat keine Parameter. Score-Anzeige erfordert einen `score`-Parameter. Evidence: `game.py:248-265` gelesen.
- FC-004 (confirmed): `main()` bei `game.py:284-303` ruft `run_phase(phase)` im Loop auf (`game.py:300-301`) ohne Rückgabewert. Score-Akkumulation erfordert `score += run_phase(phase)`. Evidence: `game.py:300-301` gelesen.
- FC-005 (confirmed): `input()` wird bereits an zwei Stellen verwendet: in `pause()` (`game.py:34`) und in `main()` für Skip-Logik (`game.py:290-293`). Das Muster ist etabliert. Evidence: `game.py:33-34`, `game.py:290-293` gelesen.
- FC-006 (confirmed): Alle Hilfsfunktionen (`clear_screen`, `pause`, `print_centered`, `print_box`, `_ANSI_RE`, `_visible_len`) bleiben unberührt — sie sind wiederverwendbar. Evidence: `game.py:29-64` gelesen.
- FC-007 (confirmed): `sys.stdout.reconfigure(encoding="utf-8", errors="replace")` steht in `main()` bei `game.py:285`. Interaktionsfunktionen profitieren davon automatisch — kein zusätzlicher Guard nötig. Evidence: `game.py:285` gelesen.

## Hypotheses

- HYP-001: Ein neues `interaktion`-Feld in jedem PHASES-Dict (statt separater Datenstruktur) ist der sauberste Ansatz — Phase-Daten und Interaktion bleiben zusammen. Bestätigung: wenn Plan diesen Weg wählt und Verifikation `game.PHASES[0]['interaktion']` funktioniert.

## Unknowns

- (keine — alle relevanten Stellen gelesen, Scope klar)

## Affected Files

| File | Action | Module | Impact | Relates To |
|:-----|:-------|:-------|:-------|:-----------|
| `game.py` | modify | main | cross-module | FR-001–FR-011 (alle) |

## Code Context

### Entry Points

| Entry Point | File | Signatur | Change |
|:------------|:-----|:---------|:-------|
| `PHASES` | `game.py:179` | `list[dict]` | Neues Feld `interaktion` pro Dict |
| `run_phase(phase)` | `game.py:229` | `def run_phase(phase) -> None` | Signatur → `-> int`; ruft Interaktion auf, gibt 0 oder 1 zurück |
| `show_summary()` | `game.py:248` | `def show_summary() -> None` | Signatur → `show_summary(score, total)`; zeigt Score an |
| `main()` | `game.py:284` | `def main() -> None` | Akkumuliert Score aus `run_phase()`-Rückgaben |

### Types & Contracts

| Type/Contract | File | Change | Impact |
|:-------------|:-----|:-------|:-------|
| `PHASES[n]` Dict-Schema | `game.py:179` | Neues Feld `interaktion: dict` hinzufügen | local |
| `run_phase()` Rückgabe | `game.py:229` | `None` → `int` (0 oder 1) | cross-module |
| `show_summary()` Parameter | `game.py:248` | kein Parameter → `(score: int, total: int)` | local |

### Patterns & Conventions

- Interaktionsdaten leben direkt im jeweiligen PHASES-Dict (`interaktion`-Schlüssel) — konsistent mit dem bestehenden Muster, alle Phasendaten zentral zu halten.
- Neue Interaktionsfunktion (z.B. `ask_question(interaktion)`) folgt dem `run_phase()`-Muster: nimmt ein Dict, gibt int zurück.
- Feedback-Texte direkt als String-Felder im `interaktion`-Dict — kein separates Mapping nötig.
- `input()` für Nutzereingabe, Strip + Lower für Robustheit (bereits in `main()` bei Zeile 293 etabliert).

## Dependencies

### Internal

| From | To | Type |
|:-----|:---|:-----|
| `main()` | `run_phase()` | import |
| `run_phase()` | `ask_question()` (neu) | import |
| `main()` | `show_summary()` | import |

### External

| Package/Service | Version | Purpose | New? |
|:----------------|:--------|:--------|:-----|
| Python stdlib (bereits vorhanden) | 3.14.3 | keine neuen Abhängigkeiten | nein |

## Data Changes

(keine — kein Datenbankzugriff, kein persistenter Zustand)

## Configuration

(keine neuen env vars oder Config-Dateien)

## Test Landscape

- **Framework**: kein Testframework (Non-Goal aus 0001, bleibt)
- **Verification**: `py -c "import game; ..."` — Funktionsexistenz + PHASES-Schema + Signaturprüfung
- **Coverage**: manueller Durchlauf für Interaktionsfluss

## Prior Art

- `run_phase()` bei `game.py:229` — direktes Vorbild für neue Interaktionsfunktion
- `input().strip().lower()` Pattern bei `game.py:293` — Eingabe-Verarbeitung bereits etabliert
- `print_box()` + ANSI-Konstanten — wiederverwendbar für Feedback-Darstellung

## System Context

```text
main()
  │
  ├─► show_intro()          (unverändert)
  │
  ├─► for phase in PHASES:
  │     run_phase(phase)    (geändert: → gibt int zurück)
  │       ├─► zeigt Phaseninfo (unverändert)
  │       └─► ask_question(phase['interaktion'])  (neu)
  │             ├─► zeigt Frage + Optionen
  │             ├─► liest input()
  │             ├─► zeigt Feedback mit SDD-Prinzip
  │             └─► gibt 0 oder 1 zurück
  │
  └─► show_summary(score, 7)  (geändert: zeigt "X von 7 richtig")
```

## Risks & Concerns

- **RISK-001 (niedrig):** `run_phase()` Signaturänderung (`None` → `int`) ist eine breaking change wenn der Code an anderen Stellen aufgerufen wird — im aktuellen Code wird sie nur in `main()` aufgerufen (`game.py:301`). Kein externes Risiko.
- **RISK-002 (niedrig):** `show_summary()` Parametererweiterung — nur in `main()` aufgerufen (`game.py:303`). Kein externes Risiko.
- **RISK-003 (mittel):** Die `interaktion`-Daten pro Phase sind inhaltlich anspruchsvoll (Fragen, Optionen, richtige Antwort, Feedback-Text) — Fehler in einem Dict-Eintrag brechen nur diese eine Phase. Mitigierung: Verifikationskommando prüft Schema aller 7 Dicts.

## Confidence

| Dimension | Score | Notes |
|:----------|------:|:------|
| Scope clarity | 20/20 | Genau eine Datei, drei Einstiegspunkte klar identifiziert |
| Pattern familiarity | 19/20 | Bestehendes `input()`-Muster direkt übertragbar |
| Dependency awareness | 20/20 | Keine neuen Abhängigkeiten, nur interne Signaturänderungen |
| Edge cases | 17/20 | Ungültige Eingaben bei `input()` (z.B. "5" statt "1-4") — braucht Retry-Loop |
| Test strategy | 18/20 | Schema-Verifikation + manuelle Durchlaufprüfung klar definiert |

- **Total**: 94/100
- **Verdict**: GO

### Types & Contracts

<!-- Interfaces, schemas, API contracts, shared types affected. -->

| Type/Contract | File | Change | Impact |
|:-------------|:-----|:-------|:-------|
| [name] | [file:line] | extend | module |

<!-- Change: create | modify | extend | deprecate -->

### Patterns & Conventions

<!-- How similar things are done in this codebase. Prose, not table — patterns need explanation. -->

- [Pattern description and where to find it]

## Dependencies

### Internal

<!-- Module-to-module dependencies relevant to this feature. -->

| From | To | Type |
|:-----|:---|:-----|
| [module] | [module] | import |

<!-- Type: import | api-call | db-access | event | config -->

### External

<!-- Third-party packages, APIs, services. -->

| Package/Service | Version | Purpose | New? |
|:----------------|:--------|:--------|:-----|
| [name] | [version] | [why needed] | yes/no |

## Data Changes

<!-- Include if the feature touches database, schemas, or shared state. -->

| Entity | Location | Change | Reversible |
|:-------|:---------|:-------|:-----------|
| [table/collection] | [DB/file] | [create/modify/delete] | yes/no |

## Configuration

<!-- Include if the feature needs new env vars, feature flags, or config changes. -->

| Config | Location | Change | Required By |
|:-------|:---------|:-------|:------------|
| [name] | [.env/config.yaml] | new | [module] |

## Test Landscape

<!-- What test infrastructure exists for the affected areas. -->

- **Framework**: <!-- jest, pytest, go test, etc. -->
- **Helpers**: <!-- relevant test utilities, fixtures, factories -->
- **Coverage**: <!-- current coverage in affected areas -->
- **Integration**: <!-- existing integration test patterns -->

## Prior Art

<!-- Similar implementations in the codebase to learn from or reuse. -->

- [description of similar feature and where to find it]

## System Context

<!-- Data/dependency flow diagram for this feature. ASCII art. -->

```text
[input] → [component] → [component] → [output]
                ↓
           [side effect]
```

## Risks & Concerns

<!-- Things that could go wrong, need special attention, or were surprising. -->

- [risk/concern and why it matters]

## Confidence

| Dimension | Score | Notes |
|:----------|------:|:------|
| Scope clarity | /20 | <!-- How well-defined is the change boundary? --> |
| Pattern familiarity | /20 | <!-- How well do existing patterns cover this work? --> |
| Dependency awareness | /20 | <!-- How well-mapped are upstream/downstream impacts? --> |
| Edge cases | /20 | <!-- How thoroughly are failure modes identified? --> |
| Test strategy | /20 | <!-- How clear is the verification approach? --> |

- **Total**: 0/100
- **Verdict**: GO or HOLD
