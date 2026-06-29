---
id: RESEARCH-0001
feature: "0001-sdd-cli-game"
title: "Sdd Cli Game"
type: research
schema_version: 2
status: completed
phase: research
created: 2026-06-26
updated: 2026-06-26
source: SPEC-0001
links: {"derived_from":["SPEC-0001"],"informed_by":[],"supersedes":[]}
based_on: {"SPEC-0001":"sha256:538d4648968cc246da72c28bba877632b4fbb3524d00528c2434acedce8abad8"}
related:
  brief: BRIEF-0001
  spec: SPEC-0001
  plan: PLAN-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Research: Sdd Cli Game

## Summary

Vollständig grünes Feld — keine existierende Python-Codebasis im Projekt. Research konzentriert sich auf die technische Laufzeitumgebung. Kernbefund: Python 3.14.3 ist installiert, `curses` ist unter Windows nicht verfügbar (fehlende `_curses`-Extension). Der gesamte Terminal-I/O muss über ANSI-Escape-Codes und `print()`/`input()` realisiert werden. Alle Dateien sind neu (action: create). Scope ist klar und überschaubar.

## Facts

- FC-001 (confirmed): Python 3.14.3 installiert unter `C:\Users\mehlem\AppData\Local\Programs\Python\Python314\python.exe`. Evidence: `py --version` → `Python 3.14.3`
- FC-002 (confirmed): `py`-Launcher ist verfügbar und löst auf Python 3.14.3 auf. Evidence: PowerShell `py --version` → `Python 3.14.3`
- FC-003 (confirmed): `curses`-Modul ist unter Windows Python 3.14.3 nicht nutzbar. Evidence: `import curses` → `ModuleNotFoundError: No module named '_curses'`
- FC-004 (confirmed): Stdlib-Kern ist vollständig verfügbar: `sys`, `os`, `time`, `textwrap`, `shutil`. Evidence: `import sys, os, time, textwrap, shutil` → `OK`
- FC-005 (confirmed): `shutil.get_terminal_size()` ist verfügbar für Terminalbreiten-Erkennung. Evidence: Teil von FC-004-geprüftem `shutil`-Modul (Python stdlib seit 3.3)
- FC-006 (confirmed): Projektverzeichnis ist vollständig leer außer SDD-Scaffolding (`.claude/`, `.features/`, `CLAUDE.md`, `.gitignore`). Evidence: `ls` Projektroot — keine `.py`-Dateien vorhanden

## Hypotheses

- HYP-001: ANSI-Escape-Codes funktionieren im Windows Terminal (Zielplattform laut Spec). Bestätigung: manueller Test `python -c "print('\033[32mGrün\033[0m')"` im Windows Terminal. Ablehnung: keine Farbe sichtbar → Fallback auf reines ASCII ohne Farbe nötig.
- HYP-002: `input()` mit "Drücke Enter um fortzufahren"-Pattern ist ausreichend für die lineare Spielinteraktion ohne plattformspezifische Tastatureingabe-Bibliotheken. Bestätigung: Spieldurchlauf funktioniert rein mit Enter-Bestätigungen.

## Unknowns

- (none — keine Unbekannten blockieren die Planung)

## Affected Files

| File | Action | Module | Impact | Relates To |
|:-----|:-------|:-------|:-------|:-----------|
| `game.py` | create | main | local | FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-007, FR-008, FR-009, FR-010 |
| `README.md` | create | docs | local | FR-007, FR-008 |

## Code Context

### Entry Points

| Entry Point | File | Signatur | Change |
|:------------|:-----|:---------|:-------|
| `main()` | `game.py` | `def main() -> None` | neu erstellen |
| `show_intro()` | `game.py` | `def show_intro() -> None` | neu erstellen |
| `run_phase(phase)` | `game.py` | `def run_phase(phase: dict) -> None` | neu erstellen |
| `show_summary(phases)` | `game.py` | `def show_summary(phases: list) -> None` | neu erstellen |

### Types & Contracts

| Type/Contract | File | Change | Impact |
|:-------------|:-----|:-------|:-------|
| Phase-Datenstruktur (dict/dataclass) | `game.py` | create | local |

### Patterns & Conventions

- Greenfield-Projekt: keine bestehenden Konventionen. Empfohlenes Muster: einzelne Datei `game.py`, prozedurale Struktur mit benannten Funktionen pro Phase — einfach weiterzugeben und zu lesen.
- ANSI-Escape-Codes direkt in `print()`-Aufrufe einbetten (kein externes Paket wie `colorama`). Konstanten für Farben am Dateianfang definieren.
- `input("\n[Enter] Weiter...")` als universelles Cross-Platform-Interaktionsmuster.

## Dependencies

### Internal

| From | To | Type |
|:-----|:---|:-----|
| `main()` | `show_intro()` | import |
| `main()` | `run_phase()` | import |
| `main()` | `show_summary()` | import |

### External

| Package/Service | Version | Purpose | New? |
|:----------------|:--------|:--------|:-----|
| Python stdlib (`sys`, `os`, `time`, `textwrap`, `shutil`) | 3.14.3 | Terminal-I/O, Textformatierung, Terminalgrößen-Erkennung | nein (stdlib) |

## Data Changes

(keine — kein Datenbankzugriff, kein persistenter Zustand in v1)

## Configuration

(keine env vars oder Config-Dateien erforderlich)

## Test Landscape

- **Framework**: kein Testframework (Spec Non-Goal: keine automatisierten Tests für Demo-Artefakt)
- **Verification**: manueller Durchlauf auf Windows Terminal + Unix — entspricht AC-004, AC-005
- **Coverage**: n/a

## Prior Art

- Kein Prior Art im Projekt (Greenfield). Referenz-Muster: klassische Python-Textadventures mit `print()`/`input()` — bewährtes, portables Muster ohne Abhängigkeiten.

## System Context

```text
Spieler startet game.py
        │
        ▼
  show_intro()          ← PTA-Geschichte + ASCII-Art
        │
        ▼
  run_phase(Brief)      ┐
  run_phase(Design)     │
  run_phase(Research)   │  je Phase: Erklärung + simulierter Prompt
  run_phase(Plan)       │
  run_phase(Implement)  │
  run_phase(Review)     │
  run_phase(Close)      ┘
        │
        ▼
  show_summary()        ← Alle 7 Phasen aufgelistet
        │
        ▼
      Ende
```

## Risks & Concerns

- **RISK-001 (mittel):** ANSI-Escape-Codes sind im Windows Terminal unterstützt, aber nicht in älteren `cmd.exe`-Fenstern. Minderung: Zielplattform laut Spec ist Windows Terminal — dokumentieren in README. Fallback: ANSI weglassen wenn `os.environ.get('TERM')` fehlt.
- **RISK-002 (niedrig):** `curses` nicht verfügbar auf Windows (FC-003). Vollständig gemindert: kein `curses` geplant, ANSI + `print()`/`input()` als Ersatz.
- **RISK-003 (niedrig):** `py`-Launcher ggf. nicht auf allen Windows-Systemen vorhanden. Minderung: README dokumentiert beide Aufrufvarianten (`py game.py` und `python game.py`).

## Confidence

| Dimension | Score | Notes |
|:----------|------:|:------|
| Scope clarity | 20/20 | Greenfield, alle Dateien neu, linearer Spielablauf klar definiert |
| Pattern familiarity | 18/20 | print/input-Pattern bekannt; ANSI-Codes auf Windows einmal testen |
| Dependency awareness | 20/20 | Nur stdlib, kein externes Paket, keine DB |
| Edge cases | 15/20 | ANSI-Fallback für altes cmd.exe identifiziert aber noch nicht spezifiziert |
| Test strategy | 17/20 | Manueller Durchlauf auf beiden Plattformen ausreichend und klar definiert |

- **Total**: 90/100
- **Verdict**: GO
