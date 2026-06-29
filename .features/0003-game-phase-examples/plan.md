---
id: PLAN-0003
feature: "0003-game-phase-examples"
title: "Game Phase Examples"
type: plan
schema_version: 2
status: completed
phase: plan
created: 2026-06-29
updated: 2026-06-29
source: RESEARCH-0003
links: {"derived_from":["RESEARCH-0003"],"informed_by":[],"supersedes":[]}
based_on: {"SPEC-0003":"sha256:d22b1e33fde5bc0d3b1e7b043734e8dc03607ee16f44a6db9d2d0546ae5abe66","RESEARCH-0003":"sha256:d27ee4f60dcd7ba93308b7bfb5c4333d4abc3ece45561fe27b23717f05fff33b"}
related:
  brief: BRIEF-0003
  spec: SPEC-0003
  research: RESEARCH-0003
  tasks: TASKS-0003
  review: REVIEW-0003
  scratchpad: SCRATCH-0003
  continuity: CONT-0003
  knowledge: KB-0003
tags: []
---

# Plan: Game Phase Examples

## Research Findings

- Einzige betroffene Datei: `game.py`. Alle Änderungen bleiben lokal.
- `PHASES`-Liste (`game.py:330–560`): 7 Dicts ohne `beispiel`-Feld — muss ergänzt werden.
- `run_phase()` (`game.py:567–588`): Beispiel-Panel wird zwischen Kernfrage-Ausgabe (Z. 577) und `ask_question()` (Z. 578) eingefügt.
- Zurück-Mechanismus: 4 abgegrenzte Stellen (`game.py:567, 580–587, 655, 656–661`), vollständig entfernbar.
- `print_box()` (`game.py:106–115`): bewährtes Panel-Rendering, wird wiederverwendet.
- Risiko: Emoji-Padding in `print_box()` — im manuellen Test zu beobachten.

## Architectural Decisions

- AD-001: `beispiel`-Daten inline in `PHASES`-Dicts speichern
  - **Decision**: Jedes Dict in `PHASES` erhält ein neues Feld `beispiel` mit 4 Strings (`po`, `entwickler`, `claude`, `artefakt`).
  - **Rationale**: Hält Daten und Phase zusammen — kein separates Lookup nötig. Folgt dem bestehenden Muster von `interaktion` im selben Dict.
  - **Alternatives considered**: Separate Konstante `BEISPIELE` als Liste — abgelehnt, weil es Daten und Phase trennt und Sync-Fehler riskiert.

- AD-002: Beispiel-Panel via `print_box()` rendern, keine neue Hilfsfunktion
  - **Decision**: `run_phase()` ruft `print_box()` direkt mit den 4 Beispiel-Zeilen auf.
  - **Rationale**: `print_box()` ist bereits erprobt und behandelt Zeilenumbruch automatisch. Eine neue Funktion wäre Overengineering für einen einmaligen Aufruf.
  - **Alternatives considered**: `show_beispiel_panel(phase)`-Hilfsfunktion — abgelehnt, kein Mehrwert bei einem einzigen Aufrufort.

- AD-003: Zurück-Mechanismus vollständig entfernen, `main()`-Loop vereinfachen
  - **Decision**: `can_go_back`-Parameter, z-Taste-Abfrage, `phase_scores`-Dict und Zurück-Logik werden entfernt. `main()` akkumuliert Score direkt mit `score += result`.
  - **Rationale**: Mit Beispiel-Panel vor der Frage wäre "Zurück" mehrdeutig (zurück zum Panel oder zur vorherigen Phase?). Linearer Ablauf ist einfacher und klarer.
  - **Alternatives considered**: Zurück nur auf Phase-Ebene (überspringt Panel) — abgelehnt, weil es Komplexität erhöht ohne klaren Nutzen.

## Implementation Phases

### PH-01: Beispieldaten in PHASES ergänzen
Fügt das `beispiel`-Feld mit den 4 abgenommenen Inhalten aus brief.md Q3 in alle 7 PHASES-Dicts ein.
- **Delivers**: FR-001, FR-003, FR-005
- **ACs covered**: AC-002, AC-003, AC-005
- **Demo**: `py -c "from game import PHASES; b = PHASES[0]['beispiel']; assert all(k in b for k in ['po','entwickler','claude','artefakt']); print('OK')"`

### PH-02: Beispiel-Panel in run_phase() anzeigen
Rendert das Panel vor `ask_question()` via `print_box()`.
- **Delivers**: FR-002, FR-006
- **ACs covered**: AC-001, AC-006
- **Demo**: `py game.py` — Beispiel-Panel erscheint automatisch vor jeder Phasenfrage.

### PH-03: Zurück-Mechanismus entfernen
Entfernt `can_go_back`, z-Taste-Abfrage, `phase_scores`-Dict und Zurück-Logik aus `run_phase()` und `main()`.
- **Delivers**: FR-004
- **ACs covered**: AC-004
- **Demo**: `py game.py` — z-Taste hat keine Wirkung; Spiel läuft linear durch.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|:-----|:-----------|:-------|:-----------|
| Emoji-Padding verschiebt Box-Rahmen | niedrig | niedrig | Manueller Test bei 80-Zeichen-Terminal; `_display_len()` ist vorhanden und kann bei Bedarf in `print_box()` eingebaut werden |
| Langer PO-Text überläuft Bildschirm | niedrig | mittel | `print_box()` bricht automatisch um; AC-006 prüft Kompaktheit explizit |
