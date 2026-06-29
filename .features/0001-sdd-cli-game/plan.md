---
id: PLAN-0001
feature: "0001-sdd-cli-game"
title: "Sdd Cli Game"
type: plan
schema_version: 2
status: completed
phase: plan
created: 2026-06-26
updated: 2026-06-26
source: RESEARCH-0001
links: {"derived_from":["RESEARCH-0001"],"informed_by":[],"supersedes":[]}
based_on: {"SPEC-0001":"sha256:538d4648968cc246da72c28bba877632b4fbb3524d00528c2434acedce8abad8","RESEARCH-0001":"sha256:aedc173af57dc3952c8d94c25ce9f750477f5ed36247a92ed5ce50ff8877384b"}
related:
  brief: BRIEF-0001
  spec: SPEC-0001
  research: RESEARCH-0001
  tasks: TASKS-0001
  review: REVIEW-0001
  scratchpad: SCRATCH-0001
  continuity: CONT-0001
  knowledge: KB-0001
tags: []
---

# Plan: Sdd Cli Game

## Research Findings

- FC-001/FC-002: Python 3.14.3 via `py`-Launcher verfügbar — alle Tasks nutzen `py game.py` als Aufruf.
- FC-003: `curses` nicht verfügbar auf Windows → kein `curses`, stattdessen ANSI-Escape-Codes + `print()`/`input()`.
- FC-004/FC-005: `sys`, `os`, `time`, `textwrap`, `shutil` vollständig verfügbar.
- FC-006: Projektverzeichnis ist leer — alle Dateien werden neu erstellt (kein Migrationsbedarf).
- HYP-001 (noch Hypothese): ANSI-Codes funktionieren im Windows Terminal — wird in T-001 beim ersten manuellen Test bestätigt.

## Architectural Decisions

- AD-001: Einzelne Datei `game.py` statt Package-Struktur
  - **Decision**: Das gesamte Spiel lebt in einer einzigen Datei `game.py`.
  - **Rationale**: Maximale Portabilität — ein Berater kann die Datei per E-Mail weitergeben. Für ein lineares Demo-Spiel ist ein Package unnötiger Overhead.
  - **Alternatives considered**: `sdd_game/`-Package mit separaten Modulen pro Phase — abgelehnt wegen Komplexität ohne Mehrwert.

- AD-002: ANSI-Escape-Codes als benannte Konstanten am Dateianfang
  - **Decision**: Farben und Formatierung als Modul-Konstanten (`GRÜN`, `ROT`, `GELB`, `FETT`, `RESET`), keine rohen Escape-Strings im Code.
  - **Rationale**: Lesbarkeit und einfaches Deaktivieren (alle Konstanten auf `""` setzen für Fallback ohne Farbe).
  - **Alternatives considered**: `colorama` (externes Paket, verboten); rohe `\033[...]`-Strings überall (unleserlich).

- AD-003: Lineares `input()`-Interaktionsmodell ("drücke Enter zum Weitermachen")
  - **Decision**: Kein plattformspezifisches Keyboard-Handling — ausschließlich `input()` für Benutzerinteraktion.
  - **Rationale**: `input()` ist 100% Cross-Platform, kein `msvcrt`/`tty`-Branching nötig. Für ein narratives Spiel reicht Enter-Bestätigung völlig.
  - **Alternatives considered**: `msvcrt.getch()` (Windows-only); `tty`+`termios` (Unix-only) — beide erfordern plattformspezifischen Code.

- AD-004: Phase-Daten als Liste von Dicts (Modul-Konstante `PHASES`)
  - **Decision**: Die 7 SDD-Phasen werden als `PHASES = [{"name": ..., "zweck": ..., "kernfrage": ..., "prompt": ...}, ...]` definiert.
  - **Rationale**: Einfach erweiterbar, kein Klassen-Boilerplate, direkt testbar mit `len(PHASES) == 7`.
  - **Alternatives considered**: Dataclasses — mehr Typsicherheit, aber überdimensioniert für 7 statische Einträge.

- AD-005: Skip-Intro via `.sdd_game_seen`-Marker-Datei im Spielverzeichnis
  - **Decision**: Beim zweiten Start prüft `main()` ob `.sdd_game_seen` im Verzeichnis existiert und bietet Überspringen an. Nach dem ersten vollständigen Intro wird die Datei angelegt.
  - **Rationale**: Kein Kommandozeilenargument nötig, funktioniert automatisch — AC-006 erfüllt ohne Nutzeraufwand.
  - **Alternatives considered**: `--skip-intro` Flag — erfordert dass der Nutzer sich das Flag merkt; weniger komfortabel.

## Phases

### PH-01: Spielgerüst und Terminal-Basis

> Addresses: FR-007, FR-008
> Acceptance: AC-007

Legt `game.py` mit allen ANSI-Konstanten, Terminal-Hilfsfunktionen (`clear_screen`, `pause`, `print_centered`, `print_box`) und dem `main()`-Skelett an. Das Spiel startet und beendet sich sauber ohne Inhalt. Basis für alle weiteren Slices.

### PH-02: Narrative Einleitung mit PTA-Geschichte

> Addresses: FR-001, FR-002, FR-009
> Acceptance: AC-001, AC-006

Implementiert `show_intro()` mit der fiktiven PTA-Berater-Geschichte, ASCII-Grafiken und dem Vibe-Coding-vs-SDD-Kontrast. Enthält die Skip-Intro-Logik (`.sdd_game_seen`-Marker). Nach diesem Slice ist der narrative Einstieg vollständig spielbar.

### PH-03: Die 7 SDD-Spielphasen

> Addresses: FR-003, FR-004, FR-005
> Acceptance: AC-002, AC-004

Definiert die `PHASES`-Datenstruktur mit allen 7 Phasen (Brief → Close) und implementiert `run_phase()`. Jede Phase zeigt Zweck, Kernfrage und einen simulierten Prompt. Keine echten `sdd`-Befehle. Nach diesem Slice ist der vollständige Spielkern durchspielbar.

### PH-04: Abschluss, Zusammenfassung und README

> Addresses: FR-006, FR-010
> Acceptance: AC-003, AC-004, AC-005, AC-007

Implementiert `show_summary()` mit Abschluss-Übersicht aller 7 Phasen. Verbindet alle Slices zu einem vollständigen End-to-End-Durchlauf. Erstellt `README.md` mit Startanleitung für Windows und Unix.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|:-----|:-------|:-----------|
| ANSI-Codes in altem cmd.exe nicht sichtbar (RISK-001) | Farbloser Output, ggf. kryptische Zeichen | README weist auf Windows Terminal hin; ANSI-Konstanten leicht auf `""` setzbar |
| `input()` konsumiert bei piped Input sofort ohne Anzeige (Verifikation) | Verifikationskommandos schwer zu automatisieren | Verifikation per `py -m py_compile` + Funktionsexistenz-Check + manueller Durchlauf |
| `.sdd_game_seen` im falschen Verzeichnis (bei verschiedenen Aufrufpfaden) | Skip-Intro funktioniert nicht zuverlässig | Marker relativ zu `__file__` ablegen, nicht zum CWD |

## Open Questions

- (none)
